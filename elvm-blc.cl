(load "./lazy.cl")
(load "./blc-numbers.cl")


;;================================================================
;; Memory and program
;;================================================================
(defrec-lazy lookup-tree* (memory address cont)
  (cond
    ((isnil memory)
      (cont int-zero))
    ((isnil address)
      (cont memory))
    (t
      (do
        (<- (car-address cdr-address) (address))
        (<- (next-memory)
          ((lambda (cont)
            (do
              (<- (car-memory cdr-memory) (memory))
              (if car-address
                (cont car-memory)
                (cont cdr-memory))))))
        (lookup-tree* next-memory cdr-address cont)))))

(defrec-lazy memory-write* (memory address value cont)
  (cond
    ((isnil address)
      (cont value))
    (t
      (do
        (<- (car-address cdr-address) (address))
        (<- (memory-rewritten memory-orig)
          (do
            (<- (memory-target)
              ((lambda (cont)
                (cond
                  ((isnil memory)
                    (cont nil nil))
                  (car-address
                    (memory cont))
                  (t
                    (do
                      (<- (car-memory cdr-memory) (memory)) ;; Implicit parameter passing: memory-orig
                      (cont cdr-memory car-memory)))))))
            (memory-write* memory-target cdr-address value)))
        (if car-address
          (cont (cons memory-rewritten memory-orig))
          (cont (cons memory-orig memory-rewritten)))))))

(defmacro-lazy eval-bool (expr)
  `(lambda (cont)
    (if ,expr
      (cont t)
      (cont nil))))

(defrec-lazy add* (initcarry is-add n m cont)
  (cond
    ((isnil n)
      (cont nil initcarry))
    (t
      (do
        (<- (car-n cdr-n) (n))
        (<- (car-m cdr-m) (m))
        (<- (curlist carry) (add* initcarry is-add cdr-n cdr-m))
        (let* not-carry (not carry))
        (let* car-m (if is-add car-m (not car-m)))
        (<- (curbit)
          ((eval-bool
            (if car-n
              (if car-m
                carry
                not-carry)
              (if car-m
                not-carry
                carry)))))
        (<- (nextcarry)
          ((eval-bool
            (if car-n
              (if car-m
                t
                carry)
              (if car-m
                carry
                nil)))))
        (cont (cons curbit curlist) nextcarry)))))



;;================================================================
;; Registers
;;================================================================
(def-lazy reg-PC (cons nil (cons nil nil)))
(def-lazy reg-A  (cons nil (cons t nil)))
(def-lazy reg-D  (cons t (cons nil (cons nil nil))))
(def-lazy reg-SP (cons t (cons nil (cons t nil))))
(def-lazy reg-B  (cons t (cons t (cons nil nil))))
(def-lazy reg-BP (4 (lambda (x f) (f t x)) nil))
(def-lazy reg-C  (cons t (cons t (cons t (cons nil nil)))))



;;================================================================
;; Arithmetic
;;================================================================
(defun-lazy cmpret-eq (r1 r2 r3) r1)
(defun-lazy cmpret-lt (r1 r2 r3) r2)
(defun-lazy cmpret-gt (r1 r2 r3) r3)

(defrec-lazy cmp* (n m)
  (do
    (if-then-return (isnil n)
      cmpret-eq)
    (<- (car-n cdr-n) (n))
    (<- (car-m cdr-m) (m))
    (let* next (cmp* cdr-n cdr-m))
    (if car-n
      (if car-m
        next
        cmpret-lt)
      (if car-m
        cmpret-gt
        next))))

(defun-lazy cmp-gt (f) (f nil nil t))
(defun-lazy cmp-lt (f) (f nil t   nil))
(defun-lazy cmp-eq (f) (f t   nil nil))
(defun-lazy cmp-le (f) (f t   t   nil))
(defun-lazy cmp-ge (f) (f t   nil t))
(defun-lazy cmp-ne (f) (f nil t   t))

(defmacro-lazy cmp (n m enum-cmp)
  `(,enum-cmp (cmp* ,n ,m)))


;;================================================================
;; I/O
;;================================================================
(defmacro-lazy io-bitlength-to-wordsize (n)
  `(supp-bitlength (lambda (x f) (f t x)) ,n))

(defmacro-lazy wordsize-to-io-bitlength (n)
  `(supp-bitlength cdr* ,n))


;;================================================================
;; Evaluation
;;================================================================
(defun-lazy lookup-src-if-imm* (reg src-is-imm *src cont)
  (if src-is-imm
    (cont *src)
    (lookup-tree* reg *src cont)))

;; (lambda (a b) z) a b c

;; z a b c = nil
;; z = t
;; a b c = t

;; a c = nil
;; a b c = t

;; i (lambda (x) t) nil



(defrec-lazy eval (memory progtree stdin curblock curproglist reg)
  (do
    (let* jumpto
      (lambda (jmp)
        (do
          ;; (<- (reg) (memory-write* reg reg-PC jmp))  ;; Implicit parameter passing: reg
          (<- (proglist) (lookup-tree* progtree jmp))     ;; Implicit parameter passing: nextblock
          (<- (nextblock curproglist) (proglist))
          (eval memory progtree stdin nextblock curproglist reg))))
    (cond
      ;; Checks if curblock is { t, nil } (returns t) or a cons cell (returns nil).
      ((curblock (lambda (a b) t) (lambda (a) a) (lambda (a) t) nil)
        (do
          (if-then-return (isnil curproglist)
            SYS-STRING-TERM)
          (<- (nextblock curproglist) (curproglist))
          (eval memory progtree stdin nextblock curproglist reg)))
      (t
        (do
          (<- (curinst nextblock) (curblock))
          (let* eval-reg (eval memory progtree stdin nextblock curproglist))
          (<- (inst-type src-is-imm *src) (curinst)) ;; Delayed destruction: *dst
          (<- (src *dst) (lookup-src-if-imm* reg src-is-imm *src))
          **instruction-typematch**)))))


;;================================================================
;; Instructions
;;================================================================
(defun-lazy inst-io      (i1 i2 i3 i4 i5 i6 i7 i8) i1)
(defun-lazy inst-jmpcmp  (i1 i2 i3 i4 i5 i6 i7 i8) i2)
(defun-lazy inst-cmp     (i1 i2 i3 i4 i5 i6 i7 i8) i3)
(defun-lazy inst-jmp     (i1 i2 i3 i4 i5 i6 i7 i8) i4)
(defun-lazy inst-load    (i1 i2 i3 i4 i5 i6 i7 i8) i5)
(defun-lazy inst-store   (i1 i2 i3 i4 i5 i6 i7 i8) i6)
(defun-lazy inst-addsub  (i1 i2 i3 i4 i5 i6 i7 i8) i7)
(defun-lazy inst-mov     (i1 i2 i3 i4 i5 i6 i7 i8) i8)

(def-lazy **instruction-typematch**
  (inst-type
    io-case
    jmpcmp-case
    cmp-case
    jmp-case
    load-case
    store-case
    addsub-case
    mov-case
    ))

(defun-lazy io-exit (x1 x2 x3) x1)
(defun-lazy io-getc (x1 x2 x3) x2)
(defun-lazy io-putc (x1 x2 x3) x3)

(defmacro-lazy cons4 (x1 x2 x3 x4)
  `(lambda (f) (f ,x1 ,x2 ,x3 ,x4)))


(def-lazy addsub-case
  ;; Instruction structure: (cons4 inst-store [src-isimm] [src] (cons [*dst] is-sub))
  (do
    (<- (*dst is-add) (*dst))
    (<- (sum carry)
      ((do
        (lookup-tree* reg *dst) ;; Implicit parameter passing: dst
        (add* is-add is-add))
       src))                    ;; Applies src to the preceding add*
    (memory-write* reg *dst sum eval-reg)))

(def-lazy store-case
  ;; Instruction structure: (cons4 inst-store [dst-isimm] [dst-memory] [source])
  ;; Note that the destination is stored in the variable *src
  (do
    (<- (memory) ((lookup-tree* reg *dst (memory-write* memory src))))
    (eval memory progtree stdin nextblock curproglist reg)))

(def-lazy mov-case
  ;; Instruction structure:: (cons4 inst-mov [src-isimm] [src] [dst])
  (memory-write* reg *dst src eval-reg))

(def-lazy jmp-case
  ;; Instruction structure:: (cons4 inst-jmp [jmp-isimm] [jmp] _)
  (jumpto src))

(def-lazy jmpcmp-case
  ;; Instruction structure: (cons4 inst-jmpcmp [src-isimm] [src] (cons4 [enum-cmp] [*dst] [jmp-isimm] [jmp]))
  (do
    (<- (enum-cmp jmp-is-imm *jmp *cmp-dst) (*dst))
    (lookup-src-if-imm* reg jmp-is-imm *jmp)  ;; Implicit parameter passing: jmp
    (lookup-tree* reg *cmp-dst)               ;; Implicit parameter passing: dst-value
    (lambda (dst-value jmp)
      (if (cmp dst-value src enum-cmp)
        (jumpto jmp)
        (eval-reg reg)))))

(def-lazy load-case
  ;; Instruction structure: (cons4 inst-load [src-isimm] [src] [*dst])
  (do
    (<- (value) (lookup-tree* memory src))
    (memory-write* reg *dst value eval-reg)))

(def-lazy cmp-case
  ;; Instruction structure: (cons4 inst-cmp [src-isimm] [src] (cons [emum-cmp] [dst]))
  (do
    (<- (enum-cmp dst) (*dst))
    (<- (dst-value) (lookup-tree* reg dst))
    (<- (sum carry) (add* nil (cmp dst-value src enum-cmp) int-zero int-zero))
    (memory-write* reg dst sum eval-reg)))

(def-lazy io-case
  ;; Instruction structure:
  ;;   getc: (cons4 inst-io nil         [dst] io-getc)
  ;;   putc: (cons4 inst-io [src-isimm] [src] io-putc)
  ;;   exit: (cons4 inst-io nil         nil   io-exit)
  ;; Typematch over the inst. type
  (*dst
    ;; getc
    (do
      (<- (c stdin)
        ((lambda (return)
          (do
            (if-then-return (isnil stdin)
              (return int-zero stdin))
            (<- (car-stdin cdr-stdin) (stdin))
            (return (io-bitlength-to-wordsize car-stdin) cdr-stdin)))))
      (memory-write* reg *src c)               ;; Implicit parameter passing: reg
      (eval memory progtree stdin nextblock curproglist))
    ;; putc
    (do
      (cons (wordsize-to-io-bitlength src) (eval-reg reg)))
    ;; exit
    SYS-STRING-TERM))


(defun-lazy list2tree*** (l depth decorator cont)
  ((letrec-lazy list2tree** (l depth cont)
    (cond
      ((isnil l)
        (cont l l))
      ((isnil depth)
        (do
          (<- (l-car l-cdr) (l))
          (<- (x) (decorator l))
          (cont x l-cdr)))
      (t
        (do
          (<- (_ cdr-depth) (depth))
          (<- (right-tree l) (list2tree** l cdr-depth))
          (<- (left-tree l) (list2tree** l cdr-depth))
          (cont (cons right-tree left-tree) l)))))
   l depth cont))


(def-lazy initreg nil)

(defun-lazy main (io-bitlength supp-bitlength memlist proglist stdin)
  (do
    ;; Share references to functions to prevent them from being inlined multiple times
    (let* Y-comb Y-comb)
    (let* cmp* cmp*)
    (let* add* add*)
    (<- (int-zero)
      ((lambda (return)
        (let ((cons-t (lambda (x f) (f t x))))
          (return (supp-bitlength cons-t (io-bitlength cons-t nil)))))))
    (<- (progtree memtree)
      ((lambda (cont)
        (do
          (let* list2tree*
            (lambda (l decorator cont)
              (do
                (<- (tree _) (list2tree*** l int-zero decorator))
                (cont tree))))
          (list2tree* memlist (lambda (x cont) (do (<- (car-x cdr-x) (x)) (cont car-x))))  ;; Implicit argument passing: memtree
          (list2tree* proglist (lambda (x cont) (cont x))
          ;; (lambda (x cont) (cont x))
          ) ;; Implicit argument passing: progtree
          (cont)))))
    (let* memory-write* memory-write*)
    (let* lookup-tree* lookup-tree*)
    (<- (curblock curproglist) (proglist))
    (eval memtree progtree stdin curblock curproglist initreg)))

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
