(load "./lazy.cl")
(load "./blc-numbers.cl")


(def-lazy SYS-N-BITS (+ 16 8))
;; (def-lazy int-zero (take SYS-N-BITS (inflist nil)))
(def-lazy int-zero
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t nil)))))))))))))))))))))))))

(def-lazy int-one
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons nil nil)))))))))))))))))))))))))

(def-lazy int-two
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons nil (cons t nil)))))))))))))))))))))))))

(def-lazy address-one
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
  (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons nil nil)))))))))))))))))))))))))

;;================================================================
;; Memory and program
;;================================================================
(defrec-lazy lookup-tree (progtree address)
  (cond
    ((isnil progtree)
      int-zero)
    ((isnil address)
      progtree)
    (t
      (lookup-tree (progtree (car address)) (cdr address)))))

(defrec-lazy lookup-memory* (progtree address cont)
  (cond
    ((isnil progtree)
      (cont int-zero))
    ((isnil address)
      (cont progtree))
    (t
      (if (car address)
        (lookup-memory* (progtree t) (cdr address) cont)
        (lookup-memory* (progtree nil) (cdr address) cont)))))

(defrec-lazy lookup-progtree (progtree address cont)
  (cond
    ((isnil progtree)
      (cont progtree))
    ((isnil address)
      (cont progtree))
    (t
      (if (car address)
        (lookup-progtree (progtree t) (cdr address) cont)
        (lookup-progtree (progtree nil) (cdr address) cont)))))

(defrec-lazy memory-write (memory address value)
  (let ((next (lambda (x) (memory-write x (cdr address) value))))
    (cond
      ((isnil address)
        value)
      ((isnil memory)
        ((car address)
          (cons (next nil) nil)
          (cons nil (next nil))))
      (t
        ((car address)
          (cons (next (car memory)) (cdr memory))
          (cons (car memory) (next (cdr memory))))))))

(defrec-lazy memory-write* (memory address value cont)
  (cond
    ((isnil address)
      (cont value))
    ((isnil memory)
      (do
        (<- (tree) (memory-write* memory (cdr address) value))
        (if (car address)
          (cont (cons tree nil))
          (cont (cons nil tree)))))
    (t
      (cond
        ((car address)
          (do
            (<- (tree) (memory-write* (car memory) (cdr address) value))
            (cont (cons tree (cdr memory)))))
        (t
          (do
            (<- (tree) (memory-write* (cdr memory) (cdr address) value))
            (cont (cons (car memory) tree))))))))


;; (defrec-lazy list2tree (memlist depth decorator)
;;   (cond
;;     ((isnil memlist)
;;       (cons nil nil))
;;     ((isnil depth)
;;       (cons (decorator memlist) (cdr memlist)))
;;     (t
;;       (let ((rightstate (list2tree memlist (cdr depth) decorator))
;;             (righttree (car rightstate))
;;             (right-restmemlist (cdr rightstate))
;;             (leftstate (list2tree right-restmemlist (cdr depth) decorator))
;;             (lefttree (car leftstate))
;;             (left-restmemlist (cdr leftstate)))
;;         (cons (cons lefttree righttree) left-restmemlist)))))

(defrec-lazy reverse** (l curlist cont)
  (if (isnil l)
    (cont curlist)
    (reverse** (cdr l) (cons (car l) curlist) cont)))

(defun-lazy reverse* (l cont)
  (reverse** l nil cont))

(defrec-lazy increment-pc-reverse (pc curlist carry cont)
  (cond
    ((isnil pc)
      (cont curlist))
    (t
      (if (not (xor (car pc) carry))
        (do
          ;; (let* curbit t)
          (if (or (car pc) carry)
            (do
              ;; (let* nextcarry t)
              (increment-pc-reverse (cdr pc) (cons t curlist) t cont))
            (do
              ;; (let* nextcarry nil)
              (increment-pc-reverse (cdr pc) (cons t curlist) nil cont))))
        (do
          ;; (let* curbit nil)
          (if (or (car pc) carry)
            (do
              ;; (let* nextcarry t)
              (increment-pc-reverse (cdr pc) (cons nil curlist) t cont))
            (do
              ;; (let* nextcarry nil)
              (increment-pc-reverse (cdr pc) (cons nil curlist) nil cont))))))))

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
        (if (xor (not (car n)) (xor (not (car m)) (not carry)))
          (do
            (let* curbit nil)
            (if (or
                  (and (car n) carry)
                  (and (car m) carry)
                  (and (car n) (car m)))
              ;; nextcarry 
              (add-reverse* (cdr n) (cdr m) (cons curbit curlist) t cont)
              (add-reverse* (cdr n) (cdr m) (cons curbit curlist) nil cont)))
          (do
            (let* curbit t)
            (if (or
                  (and (car n) carry)
                  (and (car m) carry)
                  (and (car n) (car m)))
              ;; nextcarry 
              (add-reverse* (cdr n) (cdr m) (cons curbit curlist) t cont)
              (add-reverse* (cdr n) (cdr m) (cons curbit curlist) nil cont))))))))



;;================================================================
;; Registers
;;================================================================
(def-lazy reg-A  (list nil nil nil))
(def-lazy reg-B  (list t nil nil))
(def-lazy reg-C  (list nil t nil))
(def-lazy reg-D  (list t t nil))
(def-lazy reg-SP (list nil nil t))
(def-lazy reg-BP (list t nil t))
(def-lazy reg-PC (list nil t t))


(defun-lazy reg-read (reg regptr)
  (lookup-tree reg
  regptr
  ;; (regptr2regaddr regptr)
  ))

(defun-lazy reg-write (reg value regptr)
  (memory-write reg
  regptr
  ;; (regptr2regaddr regptr)
  value))

(defun-lazy reg-read* (reg regptr cont)
  (do
    (<- (value) (lookup-memory* reg regptr))
    (cont value)))

(defun-lazy reg-write* (reg value regptr cont)
  (do
    (<- (reg) (memory-write* reg regptr value))
    (cont reg)))
;; (defun-lazy reg-write* (reg value regptr cont)
;;   (do
;;     (let* reg (memory-write reg regptr value))
;;     (cont reg)))



;;================================================================
;; Instructions
;;================================================================
(defun-lazy inst-add     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i9)
(defun-lazy inst-store   (i1 i2 i3 i4 i5 i6 i7 i8 i9) i8)
(defun-lazy inst-mov     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i7)
(defun-lazy inst-jmp     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i6)
(defun-lazy inst-jumpcmp (i1 i2 i3 i4 i5 i6 i7 i8 i9) i5)
(defun-lazy inst-load    (i1 i2 i3 i4 i5 i6 i7 i8 i9) i4)
(defun-lazy inst-cmp     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i3)
(defun-lazy inst-sub     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i2)
(defun-lazy inst-io-int  (i1 i2 i3 i4 i5 i6 i7 i8 i9) i1)

(defun-lazy io-int-putc (x1 x2 x3) x3)
(defun-lazy io-int-getc (x1 x2 x3) x2)
(defun-lazy io-int-exit (x1 x2 x3) x1)

(defmacro-lazy car4-1 (f) `(,f (lambda (x1 x2 x3 x4) x1)))
(defmacro-lazy car4-2 (f) `(,f (lambda (x1 x2 x3 x4) x2)))
(defmacro-lazy car4-3 (f) `(,f (lambda (x1 x2 x3 x4) x3)))
(defmacro-lazy car4-4 (f) `(,f (lambda (x1 x2 x3 x4) x4)))
(defmacro-lazy cons4 (x1 x2 x3 x4)
  `(lambda (f) (f ,x1 ,x2 ,x3 ,x4)))


;;================================================================
;; Arithmetic
;;================================================================
(defrec-lazy add-carry (n m carry invert)
  (cond ((isnil n)
          nil)
        (t
          (let ((next (lambda (x y) (cons x (add-carry (cdr n) (cdr m) y invert))))
                (diff (next (not carry) carry)))
            (if (xor invert (car m))
              (if (car n)
                (next carry t)
                diff)
              (if (car n)
                diff
                (next carry nil)))))))

(defmacro-lazy add (n m)
  `(add-carry ,n ,m nil nil))

(defmacro-lazy sub (n m)
  `(add-carry ,n ,m t t))

;; (defmacro-lazy increment (n)
;;   `(add-carry ,n int-zero t nil))


(defun-lazy cmpret-eq (r1 r2 r3) r1)
(defun-lazy cmpret-lt (r1 r2 r3) r2)
(defun-lazy cmpret-gt (r1 r2 r3) r3)

(defrec-lazy cmp* (n m)
  (cond ((isnil n)
          cmpret-eq)
        (t
          (let ((ncar (car n))
                (mcar (car m)))
            (cond ((and (not ncar) mcar)
                    cmpret-lt)
                  ((and ncar (not mcar))
                    cmpret-gt)
                  (t
                    (cmp* (cdr n) (cdr m))))))))

(defun-lazy cmp-gt (x1 x2 x3 x4 x5 x6) x6)
(defun-lazy cmp-lt (x1 x2 x3 x4 x5 x6) x5)
(defun-lazy cmp-eq (x1 x2 x3 x4 x5 x6) x4)
(defun-lazy cmp-le (x1 x2 x3 x4 x5 x6) x3)
(defun-lazy cmp-ge (x1 x2 x3 x4 x5 x6) x2)
(defun-lazy cmp-ne (x1 x2 x3 x4 x5 x6) x1)

(defun-lazy cmp (n m enum-cmp)
  ((cmp* (reverse n) (reverse m))
    (enum-cmp nil t   t   t   nil nil)
    (enum-cmp t   nil t   nil t   nil)
    (enum-cmp t   t   nil nil nil t  )))


;;================================================================
;; I/O
;;================================================================
;; (def-lazy powerlist
;;   ((letrec-lazy powerlist (n bits)
;;     (cond ((isnil bits)
;;             nil)
;;           (t
;;             (cons n (powerlist (+ n n) (cdr bits))))))
;;     1 (take 8 (inflist t))))

;; (def-lazy revpowerlist
;;   (reverse powerlist))

;; (defrec-lazy bit2int* (n powerlist)
;;   (let ((next (bit2int* (cdr n) (cdr powerlist))))
;;     (cond ((isnil powerlist)
;;             0)
;;           ((car n)
;;             (+ (car powerlist) next))
;;           (t
;;             next))))

;; (defmacro-lazy bit2int (n)
;;   `(bit2int* ,n powerlist))

;; (defrec-lazy int2bit* (n revpowerlist)
;;   (let ((next (lambda (x) (int2bit* x (cdr revpowerlist)))))
;;     (cond ((isnil revpowerlist)
;;             nil)
;;           ((<= (car revpowerlist) n)
;;             (cons t (next (- n (car revpowerlist)))))
;;           (t
;;             (cons nil (next n))))))

;; (defmacro-lazy int2bit (n)
;;   `(reverse-helper (int2bit* ,n revpowerlist) (take 16 (inflist nil))))

(defrec-lazy invert-bits* (n curlist cont)
  (cond
    ((isnil n)
      (do
        (<- (ret) (reverse* curlist))
        (cont ret)))
    (t
      (invert-bits* (cdr n) (cons (not (car n)) curlist) cont))))

(defrec-lazy invert-bits-rev* (n curlist cont)
  (cond
    ((isnil n)
      (cont curlist))
    (t
      (do
        (let* x (not (car n)))
        (let* x (cons x curlist))
        (invert-bits-rev* (cdr n) x cont)))))


(defun-lazy 8-to-24-bit* (n cont)
  (do
    ;; (<- (n-inv) (invert-bits* n nil))
    ;; (let* ret-rev
    ;;   )
    ;; (<- (ret) (reverse* ret-rev))
    (cont
      (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t 
      (cons t (cons t (cons t (cons t (cons t (cons t (cons t (cons t n)))))))))))))))))))

(defun-lazy 24-to-8-bit* (n-rev cont)
  (do
    ;; (<- (n-rev) (invert-bits-rev* n nil))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))

    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))

    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))

    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))
    (let* ret (cdr n-rev))

    (cont ret)))

(defun-lazy 8-to-24-bit (n)
  (8-to-24-bit* n (lambda (x) x)))

(defun-lazy 24-to-8-bit (n)
  (24-to-8-bit* n (lambda (x) x)))

;;================================================================
;; Evaluation
;;================================================================
(defmacro-lazy await (stdin-top body)
  ;; The key ingredient to managing the I/O control flow.
  ;; By inspecting the value of the top character of the standard input and branching depending on its value,
  ;; `await` is able to halt the further execution of `body` until the input is actually provided.
  ;; Since elements of `stdin` are always a number, this form is guaranteed to evaluate to `body`.
  ;; However, since most interpreters do not use that fact during beta reduction
  ;; and expect `stdin` to be an arbitrary lambda form,
  ;; such interpreters cannot deduce that this form always reduces to `body`,
  ;; effectively making this form a method for halting evaluation until the standard input is provided.
  `(if (iszero (succ ,stdin-top))
    nil
    ,body))

(defrec-lazy flatten (curlist listlist)
  (cond ((isnil curlist)
          (if (isnil listlist)
            nil
            (flatten (car listlist) (cdr listlist))))
        (t
          (cons (car curlist) (flatten (cdr curlist) listlist)))))

(defrec-lazy eval (reg memory progtree stdin curblock)
  (cons "E" (cond ((isnil curblock)
          (cons "N"
            (do
              (<- (pc) (reg-read* reg reg-PC))
              (<- (nextpc) (increment-pc* pc))
              (<- (nextblock) (lookup-progtree progtree nextpc))
              (cond
                ((isnil nextblock)
                  (cons "T" SYS-STRING-TERM))
                (t
                  (cons "P"
                    (do
                      (<- (reg) (reg-write* reg nextpc reg-PC))
                      (eval reg memory progtree stdin nextblock))))))))
        (t
          ;; Prevent frequently used functions from being inlined every time
          (let ((lookup-tree lookup-tree)
                (memory-write memory-write)
                (reverse-helper reverse-helper)
                (expand-prog-at (lambda (pc) (lookup-progtree progtree pc)))
                ;; (powerlist powerlist)
                (add-carry add-carry)
                (cmp cmp)
                (reg-read reg-read)
                (curinst (car curblock))
                (*src (car4-3 curinst))
                (src (if (car4-2 curinst) *src (reg-read reg *src)))
                (*dst (car4-4 curinst))
                (nextblock (cdr curblock))
                (eval-reg-write
                  (lambda (src dst)
                    (do
                      (<- (reg) (reg-write* reg src dst))
                      (eval reg memory progtree stdin nextblock)))))
            ;; Typematch on the current instruction's tag
            ((car4-1 curinst)
              ;; ==== inst-io-int ====
              ;; Instruction structure:
              ;;   exit: (cons4 inst-io-int nil         nil   io-int-exit)
              ;;   getc: (cons4 inst-io-int nil         [dst] io-int-getc)
              ;;   putc: (cons4 inst-io-int [src-isimm] [src] io-int-putc)
              ;; Typematch over the inst. type
              (*dst
                ;; exit
                SYS-STRING-TERM
                ;; getc
                (cons "G"
                  (cond ((isnil stdin)
                          (eval-reg-write int-zero *src))
                        (t
                          (do
                            (<- (c) (8-to-24-bit* (car stdin)))
                            (<- (reg) (reg-write* reg c *src))
                            (eval reg memory progtree (cdr stdin) nextblock)))))
                ;; putc
                (cons "C" (do
                  (<- (c) (24-to-8-bit* src))
                  (cons c (eval reg memory progtree stdin nextblock)))))

              ;; ==== inst-sub ====
              ;; Instruction structure: (cons4 inst-store [src-isimm] [src] [*dst])
              (do
                (<- (v-dst) (reg-read* reg *dst))
                (<- (v-dst-rev) (reverse* v-dst))
                (<- (v-src-rev) (invert-bits-rev* src nil))
                (<- (x) (add-reverse* v-src-rev v-dst-rev nil nil))
                (<- (reg) (reg-write* reg x *dst))
                (eval reg memory progtree stdin nextblock))

              ;; ==== inst-cmp ====
              ;; Instruction structure: (cons4 inst-cmp [src-isimm] [src] (cons [emum-cmp] [dst]))
              (let ((*dst-cmp (cdr *dst))
                    (cmp-result (cmp (reg-read reg *dst-cmp) src (car *dst))))
                (eval-reg-write
                  (if cmp-result (cons t (cdr int-zero)) int-zero)
                  *dst-cmp))

              ;; ==== inst-load ====
              ;; Instruction structure:: (cons4 inst-load [src-isimm] [src] [*dst])
              (do
                (<- (value) (lookup-memory* memory src))
                (<- (reg) (reg-write* reg value *dst))
                (eval reg memory progtree stdin nextblock))

              ;; ==== inst-jumpcmp ====
              ;; Instruction structure: (cons4 inst-jumpcmp [src-isimm] [src] (cons4 [enum-cmp] [*dst] [jmp-isimm] [jmp]))
              
              ;; TODO: rewrite PC on jump
              ;; TODO: do not use expand-prog-at
              (do
                (let* *jmp (car4-4 *dst))
                (<- (dst-value) (reg-read* reg (car4-2 *dst)))
                (if (car4-3 *dst)
                  (do
                    (let* jmp *jmp)
                    (if (cmp dst-value src (car4-1 *dst))
                      (do
                        (<- (reg) (reg-write* reg jmp reg-PC))
                        (<- (nextblock) (lookup-progtree progtree src))
                        (cons "J" (eval reg memory progtree stdin nextblock)))
                      (do
                        (eval reg memory progtree stdin nextblock)))))
                  (do
                    (<- (jmp) (reg-read* reg *jmp))
                    (if (cmp dst-value src (car4-1 *dst))
                      (do
                        (<- (reg) (reg-write* reg jmp reg-PC))
                        (<- (nextblock) (lookup-progtree progtree src))
                        (cons "J" (eval reg memory progtree stdin nextblock)))
                      (do
                        (eval reg memory progtree stdin nextblock)))))
              

              ;; ==== inst-jmp ====
              ;; Instruction structure:: (cons4 inst-jmp [jmp-isimm] [jmp] _)
              (do
                (<- (reg) (reg-write* reg src reg-PC))
                (<- (nextblock) (lookup-progtree progtree src))
                (cons "J" (eval reg memory progtree stdin nextblock)))

              ;; ==== inst-mov ====
              ;; Instruction structure:: (cons4 inst-mov [src-isimm] [src] [dst])
              (do
                (<- (reg) (reg-write* reg src *dst))
                (eval reg memory progtree stdin nextblock))

              ;; ==== inst-store ====
              ;; Instruction structure: (cons4 inst-store [dst-isimm] [dst-memory] [source])
              ;; Note that the destination is stored in the variable *src
              (do
                (<- (value) (reg-read* reg *dst))
                (<- (memory) (memory-write* memory src value))
                (eval reg memory progtree stdin nextblock))

              ;; ==== inst-add ====
              ;; Instruction structure: (cons4 inst-store [src-isimm] [src] [*dst])
              (do
                (<- (v-dst) (reg-read* reg *dst))
                (<- (v-dst-rev) (reverse* v-dst))
                (<- (v-src-rev) (reverse* src))
                (<- (x) (add-reverse* v-src-rev v-dst-rev nil t))
                (<- (reg) (reg-write* reg x *dst))
                (eval reg memory progtree stdin nextblock))))))))


(defun-lazy main (memtree progtree stdin)
  (do
    (let* take take)
    (let* int-zero int-zero)
    (<- (S-24bit) (8-to-24-bit* "S"))
    (<- (A-24bit) (8-to-24-bit* "A"))
    (eval
      nil
      ;; (car (list2tree memlist int-zero car*))
      ;; (car (list2tree proglist int-zero (lambda (x) x)))
      memtree
      ;; progree
      (cons (cons (cons (cons (cons (cons (cons (cons 
      (cons (cons (cons (cons (cons (cons (cons (cons 
      (cons (cons (cons (cons (cons (cons (cons (cons
        (list
          ;; (cons4 inst-io-int t S-24bit io-int-putc)
          ;; (cons4 inst-mov t A-24bit reg-A)
          ;; (cons4 inst-add t int-two reg-A)
          ;; (cons4 inst-io-int nil reg-A io-int-putc)
          ;; (cons4 inst-add t int-two reg-A)
          ;; (cons4 inst-io-int nil reg-A io-int-putc)
          ;; (cons4 inst-add t int-two reg-A)
          ;; (cons4 inst-io-int nil reg-A io-int-putc)
          ;; (cons4 inst-add t int-two reg-A)
          ;; (cons4 inst-io-int nil reg-A io-int-putc)
          (cons4 inst-io-int nil reg-A io-int-getc)
          (cons4 inst-mov nil reg-A reg-C)
          (cons4 inst-store t int-zero reg-C)
          )
        (list
          (cons4 inst-load t int-zero reg-B)
          (cons4 inst-io-int nil reg-B io-int-putc)
          (cons4 inst-sub t int-one reg-B)
          (cons4 inst-store t int-zero reg-B)

          ;; (cons4 inst-jumpcmp [src-isimm] [src] (cons4 [enum-cmp] [*dst] [jmp-isimm] [jmp]))
          (cons4 inst-jumpcmp t int-one (cons4 cmp-gt reg-A t int-one))
          )      
      )
      nil) nil) nil) nil) nil) nil) nil)
      nil) nil) nil) nil) nil) nil) nil) nil)
      nil) nil) nil) nil) nil) nil) nil) nil)

      ;; (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil 
      ;; (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil 
      ;; (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil (cons nil (cons
      ;;     ))))))))))))))))))))))))
      ;; nil
      stdin
      (list
        (cons4 inst-io-int t A-24bit io-int-putc)
        (cons4 inst-io-int t A-24bit io-int-putc)
        ;; (cons4 inst-mov t (8-to-24-bit "J") reg-A)
        ;; (cons4 inst-io-int nil reg-A io-int-putc)
        ;; (cons4 inst-io-int nil reg-B io-int-getc)
        ;; (cons4 inst-io-int nil reg-B io-int-putc)
        ;; (cons4 inst-io-int t (8-to-24-bit "I") io-int-putc)
        ;; (cons4 inst-io-int t (8-to-24-bit "B") io-int-putc)
        (cons4 inst-jmp t int-zero nil)))
    )
  )

(defun-lazy debug (stdin)
  (do
    (main nil nil stdin)))

(def-lazy SYS-STRING-TERM nil)

(def-lazy "*" (cons t (cons t (cons nil (cons t (cons nil (cons t (cons nil (cons t nil)))))))))



;;================================================================
;; Code output
;;================================================================
;; (format t (compile-to-ski-lazy main))
;; (format t (compile-to-ski-lazy main))
(format t (compile-to-blc-lazy debug))

;; ;; Print lambda term
;; (setf *print-right-margin* 800)
;; (format t (write-to-string (curry (macroexpand-lazy main))))

;; ;; Print in curried De Bruijn notation
;; (format t (write-to-string (to-de-bruijn (curry (macroexpand-lazy main)))))
