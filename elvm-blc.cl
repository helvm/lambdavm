(load "./lazy.cl")
(load "./blc-numbers.cl")


(defmacro-lazy cons-cdr-only (x)
  `(lambda (f) (f f ,x)))

(defmacro-lazy new-bintree-node (a b)
  `(cons-cdr-only
    (lambda (x cont)
      (if x
        (cont ,a)
        (cont ,b)))))

(defun-lazy new-bintree-node** (a b)
  (cons-cdr-only
    (lambda (x cont)
      (if x
        (cont a)
        (cont b)))))

(def-lazy int-zero (16 (new-bintree-node** t) (8 (new-bintree-node** t) nil)))
(def-lazy int-one
  (16 (new-bintree-node** t)
    (4 (new-bintree-node** t)
      (2 (new-bintree-node** t)
        (new-bintree-node** t
          (new-bintree-node** nil nil))))))


;;================================================================
;; Memory and program
;;================================================================
(defun-lazy eval-bool (expr cont)
  (if expr
    (cont t)
    (cont nil)))

(defun-lazy lookup-tree-template (default)
  (letrec-lazy lookup-memory* (memory address cont)
    (cond
      ((isnil memory)
        (cont default))
      ((isnil address)
        (cont memory))
      (t
        (do
          (<- (car-address) ((cdr address) t))
          (<- (cdr-address) ((cdr address) nil))
          (<- (next-memory) ((lambda (cont)
            (do
              (<- (car-memory cdr-memory) (memory))
              (if car-address
                (cont car-memory)
                (cont cdr-memory))))))
          ;; (let* next-memory (memory car-address))
          (lookup-memory* next-memory cdr-address cont))))))

(defun-lazy lookup-memory* (memory address cont)
  ((lookup-tree-template int-zero) memory address cont))

(defun-lazy lookup-progtree (memory address cont)
  ((lookup-tree-template nil) memory address cont))

(defrec-lazy memory-write* (memory address value cont)
  (cond
    ((isnil address)
      (cont value))
    (t
      (do
        (<- (car-address) ((cdr address) t))
        (<- (cdr-address) ((cdr address) nil))
        (<- (memory-orig memory-target) ((lambda (cont)
          (cond
            ((isnil memory)
              (cont nil nil))
            (t
              (do
                (<- (car-memory cdr-memory) (memory))
                (if car-address
                  (cont cdr-memory car-memory)
                  (cont car-memory cdr-memory))))))))
        (<- (memory-rewritten) (memory-write* memory-target cdr-address value))
        (if car-address
          (cont (cons memory-rewritten memory-orig))
          (cont (cons memory-orig memory-rewritten)))))))

(defrec-lazy reverse-generator* (g curgen cont)
  (if (isnil g)
    (cont curgen)
    (do
      (<- (car-g) ((cdr g) t))
      (<- (cdr-g) ((cdr g) nil))
      (reverse-generator* cdr-g (new-bintree-node** car-g curgen) cont))))

(defun-lazy reverse* (l cont)
  (reverse-generator* l nil cont))


(defrec-lazy increment-pc-reverse (pc curlist carry cont)
  (cond
    ((isnil pc)
      (cont curlist))
    (t
      (do
        (<- (car-pc) ((cdr pc) t))
        (<- (cdr-pc) ((cdr pc) nil))
        (<- (curbit) (eval-bool (not (xor car-pc carry))))
        (<- (nextcarry) (eval-bool (or car-pc carry)))
        (increment-pc-reverse cdr-pc (new-bintree-node curbit curlist) nextcarry cont)))))

(defun-lazy increment-pc* (pc cont)
  (do
    (<- (pc) (reverse* pc))
    (<- (pc-rev) (increment-pc-reverse pc nil nil))
    (cont pc-rev)))

(defrec-lazy add-reverse* (n m curlist carry cont)
  (cond
    ((isnil n)
      (cont curlist))
    (t
      (do
        (<- (car-n) ((cdr n) t))
        (<- (cdr-n) ((cdr n) nil))
        (<- (car-m) ((cdr m) t))
        (<- (cdr-m) ((cdr m) nil))
        (<- (curbit) (eval-bool (not (xor (not car-n) (xor (not car-m) (not carry))))))
        (<- (nextcarry) (eval-bool (or
                                    (and car-n carry)
                                    (and car-m carry)
                                    (and car-n car-m))))
        (add-reverse* cdr-n cdr-m (new-bintree-node curbit curlist) nextcarry cont)))))



;;================================================================
;; Registers
;;================================================================
;; (def-lazy reg-A  (lambda (x) (x nil nil nil)))
;; (def-lazy reg-B  (lambda (x) (x t   nil nil)))
;; (def-lazy reg-C  (lambda (x) (x nil t   nil)))
;; (def-lazy reg-D  (lambda (x) (x t   t   nil)))
;; (def-lazy reg-SP (lambda (x) (x nil nil t  )))
;; (def-lazy reg-BP (lambda (x) (x t   nil t  )))
;; (def-lazy reg-PC (lambda (x) (x nil t   t  )))

(def-lazy reg-A  (lambda (x) (x nil nil nil)))
(def-lazy reg-B  (lambda (x) (x t   nil nil)))
(def-lazy reg-C  (lambda (x) (x nil t   nil)))
(def-lazy reg-D  (lambda (x) (x t   t   nil)))
(def-lazy reg-SP (lambda (x) (x nil nil t  )))
(def-lazy reg-BP (lambda (x) (x t   nil t  )))
(def-lazy reg-PC (lambda (x) (x nil t   t  )))

(defun-lazy regcode-to-regptr (regcode)
  (regcode (lambda (x y z) (new-bintree-node** x (new-bintree-node** y (new-bintree-node** z nil))))))

(defun-lazy reg-read* (reg regptr cont)
  (do
    (<- (value) (lookup-memory* reg (regcode-to-regptr regptr)))
    (cont value)))

(defun-lazy reg-write* (reg value regptr cont)
  (do
    (<- (reg) (memory-write* reg (regcode-to-regptr regptr) value))
    (cont reg)))


;;================================================================
;; Arithmetic
;;================================================================
(defun-lazy cmpret-eq (r1 r2 r3) r1)
(defun-lazy cmpret-lt (r1 r2 r3) r2)
(defun-lazy cmpret-gt (r1 r2 r3) r3)

(defrec-lazy cmp* (n m)
  (cond ((isnil n)
          cmpret-eq)
        (t
          (do
            (<- (car-n) ((cdr n) t))
            (<- (cdr-n) ((cdr n) nil))
            (<- (car-m) ((cdr m) t))
            (<- (cdr-m) ((cdr m) nil))
            (cond ((and (not car-n) car-m)
                    cmpret-gt)
                  ((and car-n (not car-m))
                    cmpret-lt)
                  (t
                    (cmp* cdr-n cdr-m)))))))

(defun-lazy cmp-gt (x1 x2 x3 x4 x5 x6) x6)
(defun-lazy cmp-lt (x1 x2 x3 x4 x5 x6) x5)
(defun-lazy cmp-eq (x1 x2 x3 x4 x5 x6) x4)
(defun-lazy cmp-le (x1 x2 x3 x4 x5 x6) x3)
(defun-lazy cmp-ge (x1 x2 x3 x4 x5 x6) x2)
(defun-lazy cmp-ne (x1 x2 x3 x4 x5 x6) x1)

(defun-lazy cmp (n m enum-cmp)
  ((cmp* n m)
    (enum-cmp nil t   t   t   nil nil)
    (enum-cmp t   nil t   nil t   nil)
    (enum-cmp t   t   nil nil nil t  )))


;;================================================================
;; I/O
;;================================================================
(defrec-lazy invert-bits-rev* (n curlist cont)
  (cond
    ((isnil n)
      (cont curlist))
    (t
      (do
        (<- (car-n) ((cdr n) t))
        (<- (cdr-n) ((cdr n) nil))
        (<- (not-car-n) (eval-bool (not car-n)))
        (invert-bits-rev* cdr-n (new-bintree-node not-car-n curlist) cont)))))

(defrec-lazy listint-to-gen-rev* (l curgen cont)
  (cond
    ((isnil l)
      (cont curgen))
    (t
      (do
        (<- (car-l) (eval-bool (car l)))
        (listint-to-gen-rev* (cdr l) (new-bintree-node car-l curgen) cont)))))

(defun-lazy 8-to-24-bit* (n cont)
  (do
    (<- (rev-gen) (listint-to-gen-rev* (16 (cons* t) n) nil))
    (<- (gen) (reverse* rev-gen))
    (cont gen)))

(defrec-lazy gen2list (gen)
  (if (isnil gen)
    nil
    (do
      (<- (car-gen) ((cdr gen) t))
      (<- (cdr-gen) ((cdr gen) nil))
      (cons car-gen (gen2list cdr-gen)))))

(defun-lazy 24-to-8-bit* (n cont)
  (cont (16 cdr* (gen2list n))))


;;================================================================
;; Evaluation
;;================================================================
(defun-lazy lookup-src-if-imm (reg src-is-imm *src cont)
  (if src-is-imm
    (cont *src)
    (do
      (<- (src) (reg-read* reg *src))
      (cont src))))

(defrec-lazy eval (reg memory progtree stdin curblock)
  (cond
    ((isnil curblock)
      (do
        (<- (pc) (reg-read* reg reg-PC))
        (<- (nextpc) (increment-pc* pc))
        (<- (nextblock) (lookup-progtree progtree nextpc))
        (if-then-return (isnil nextblock)
          SYS-STRING-TERM)
        (<- (reg) (reg-write* reg nextpc reg-PC))
        (eval reg memory progtree stdin nextblock)))
    (t
      (do
        (<- (curinst nextblock) (curblock))
        ;; (<- (curinst) ((cdr curblock) t))
        (<- (inst-type src-is-imm *src *dst) (curinst))
        ;; (let* *src (car4-3 curinst))
        ;; (<- (src) (lookup-src-if-imm reg (car4-2 curinst) *src))
        ;; (let* *dst (car4-4 curinst))
        (<- (src) (lookup-src-if-imm reg src-is-imm *src))
        ;; (<- (nextblock) ((cdr curblock) nil))
        ;; Typematch on the current instruction's tag
        **instruction-typematch**))))

;;================================================================
;; Instructions
;;================================================================
(defun-lazy inst-io-int  (i1 i2 i3 i4 i5 i6 i7 i8 i9) i1)
(defun-lazy inst-sub     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i2)
(defun-lazy inst-jumpcmp (i1 i2 i3 i4 i5 i6 i7 i8 i9) i3)
(defun-lazy inst-cmp     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i4)
(defun-lazy inst-jmp     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i5)
(defun-lazy inst-load    (i1 i2 i3 i4 i5 i6 i7 i8 i9) i6)
(defun-lazy inst-store   (i1 i2 i3 i4 i5 i6 i7 i8 i9) i7)
(defun-lazy inst-add     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i8)
(defun-lazy inst-mov     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i9)

(def-lazy **instruction-typematch**
  (inst-type
    io-int-case
    sub-case
    jumpcmp-case
    cmp-case
    jmp-case
    load-case
    store-case
    add-case
    mov-case
    ))

(defun-lazy io-int-putc (x1 x2 x3) x3)
(defun-lazy io-int-getc (x1 x2 x3) x2)
(defun-lazy io-int-exit (x1 x2 x3) x1)

(defmacro-lazy car4-1 (f) `(,f (lambda (x1 x2 x3 x4) x1)))
(defmacro-lazy car4-2 (f) `(,f (lambda (x1 x2 x3 x4) x2)))
(defmacro-lazy car4-3 (f) `(,f (lambda (x1 x2 x3 x4) x3)))
(defmacro-lazy car4-4 (f) `(,f (lambda (x1 x2 x3 x4) x4)))
(defmacro-lazy cons4 (x1 x2 x3 x4)
  `(lambda (f) (f ,x1 ,x2 ,x3 ,x4)))

(defmacro-lazy cons4 (x1 x2 x3 x4)
  `(lambda (f) (f ,x1 ,x2 ,x3 ,x4)))


(def-lazy add-case
  ;; Instruction structure: (cons4 inst-store [src-isimm] [src] [*dst])
  (do
    (<- (v-dst) (reg-read* reg *dst))
    (<- (v-dst-rev) (reverse* v-dst))
    (<- (v-src-rev) (reverse* src))
    (<- (x) (add-reverse* v-src-rev v-dst-rev nil t))
    (<- (reg) (reg-write* reg x *dst))
    (eval reg memory progtree stdin nextblock)))

(def-lazy store-case
  ;; Instruction structure: (cons4 inst-store [dst-isimm] [dst-memory] [source])
  ;; Note that the destination is stored in the variable *src
  (do
    (<- (value) (reg-read* reg *dst))
    (<- (memory) (memory-write* memory src value))
    (eval reg memory progtree stdin nextblock)))

(def-lazy mov-case
  ;; Instruction structure:: (cons4 inst-mov [src-isimm] [src] [dst])
  (do
    (<- (reg) (reg-write* reg src *dst))
    (eval reg memory progtree stdin nextblock)))

(def-lazy jmp-case
  ;; Instruction structure:: (cons4 inst-jmp [jmp-isimm] [jmp] _)
  (do
    (<- (reg) (reg-write* reg src reg-PC))
    (<- (nextblock) (lookup-progtree progtree src))
    (eval reg memory progtree stdin nextblock)))

(def-lazy jumpcmp-case
  ;; Instruction structure: (cons4 inst-jumpcmp [src-isimm] [src] (cons4 [enum-cmp] [*dst] [jmp-isimm] [jmp]))
  (do
    (let* *jmp (car4-4 *dst))
    (<- (jmp) (lookup-src-if-imm reg (car4-3 *dst) *jmp))
    (<- (dst-value) (reg-read* reg (car4-2 *dst)))
    (<- (reg nextblock) ((lambda (cont)
      (if (cmp dst-value src (car4-1 *dst))
        (do
          (<- (reg) (reg-write* reg jmp reg-PC))
          (<- (nextblock) (lookup-progtree progtree jmp))
          (cont reg nextblock))
        (cont reg nextblock)))))
    (eval reg memory progtree stdin nextblock)))

(def-lazy load-case
  ;; Instruction structure:: (cons4 inst-load [src-isimm] [src] [*dst])
  (do
    (<- (value) (lookup-memory* memory src))
    (<- (reg) (reg-write* reg value *dst))
    (eval reg memory progtree stdin nextblock)))

(def-lazy cmp-case
  ;; Instruction structure: (cons4 inst-cmp [src-isimm] [src] (cons [emum-cmp] [dst]))
  (do
    (let* *dst-cmp (cdr *dst))
    (<- (dst-value) (reg-read* reg *dst-cmp))
    (<- (ret) ((lambda (cont)
      (if (cmp dst-value src (car *dst))
        (cont int-one)
        (cont int-zero)))))
    (<- (reg) (reg-write* reg ret *dst-cmp))
    (eval reg memory progtree stdin nextblock)))

(def-lazy sub-case
  ;; Instruction structure: (cons4 inst-store [src-isimm] [src] [*dst])
  (do
    (<- (v-dst) (reg-read* reg *dst))
    (<- (v-dst-rev) (reverse* v-dst))
    (<- (v-src-rev) (invert-bits-rev* src nil))
    (<- (x) (add-reverse* v-src-rev v-dst-rev nil nil))
    (<- (reg) (reg-write* reg x *dst))
    (eval reg memory progtree stdin nextblock)))

(def-lazy io-int-case
  ;; Instruction structure:
  ;;   exit: (cons4 inst-io-int nil         nil   io-int-exit)
  ;;   getc: (cons4 inst-io-int nil         [dst] io-int-getc)
  ;;   putc: (cons4 inst-io-int [src-isimm] [src] io-int-putc)
  ;; Typematch over the inst. type
  (*dst
    ;; exit
    SYS-STRING-TERM
    ;; getc
    (do
      (<- (c stdin) ((lambda (cont)
        (if (isnil stdin)
          (cont int-zero stdin)
          (do
            (<- (c) (8-to-24-bit* (car stdin)))
            (cont c (cdr stdin)))))))
      (<- (reg) (reg-write* reg c *src))
      (eval reg memory progtree stdin nextblock))
    ;; putc
    (do
      (<- (c) (24-to-8-bit* src))
      (cons c (eval reg memory progtree stdin nextblock)))))


(defun-lazy main (memtree progtree-cont stdin)
  (do
    ;; Share references to functions to prevent them from being inlined multiple times
    (let* cmp cmp)
    (let* add-reverse* add-reverse*)
    (let* new-bintree-node** new-bintree-node**)
    (let* int-zero int-zero)
    (let* int-one int-one)
    (let* lookup-tree-template lookup-tree-template)
    (let* lookup-memory* lookup-memory*)
    (let* lookup-progtree lookup-progtree)
    (let* memory-write* memory-write*)
    (let* reverse* reverse*)
    (let* reg-read* reg-read*)
    (let* reg-write* reg-write*)
    (eval
      nil
      memtree
      progtree-cont
      stdin
      (list (cons4 inst-jmp t int-zero nil)))))

(def-lazy SYS-STRING-TERM nil)


;;================================================================
;; Code output
;;================================================================
;; (format t (compile-to-ski-lazy main))
;; (format t (compile-to-ski-lazy main))
(format t (compile-to-blc-lazy main))

;; ;; Print lambda term
;; (setf *print-right-margin* 800)
;; (format t (write-to-string (curry (macroexpand-lazy main))))

;; ;; Print in curried De Bruijn notation
;; (format t (write-to-string (to-de-bruijn (curry (macroexpand-lazy main)))))
