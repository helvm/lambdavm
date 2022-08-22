(load "./lazy.cl")


(def-lazy SYS-N-BITS (+ 16 8))
(def-lazy int-zero (take SYS-N-BITS (inflist nil)))


;;================================================================
;; Memory and program
;;================================================================
(def-lazy init-memory nil)

;; (defrec-lazy memory-read (memory address)
;;   (cond
;;     ((isnil memory)
;;       int-zero)
;;     ((isnil address)
;;       memory)
;;     (t
;;       (memory-read (memory (car address)) (cdr address)))))

(defrec-lazy lookup-tree (progtree address)
  (cond
    ((isnil progtree)
      progtree)
    ((isnil address)
      progtree)
    (t
      (lookup-tree (progtree (car address)) (cdr address)))))

(defrec-lazy memory-write (memory address value)
  (cond
    ((isnil address)
      value)
    ((isnil memory)
      ((car address)
        (cons (memory-write nil (cdr address) value) nil)
        (cons nil (memory-write nil (cdr address) value))))
    (t
      ((car address)
        (cons (memory-write (car memory) (cdr address) value) (cdr memory))
        (cons (car memory) (memory-write (cdr memory) (cdr address) value))))))

(defrec-lazy list2tree (memlist depth decorator)
  (cond
    ((isnil memlist)
      (cons nil nil))
    ((isnil depth)
      (cons (decorator memlist) (cdr memlist)))
    (t
      (let ((rightstate (list2tree memlist (cdr depth) decorator))
            (righttree (car rightstate))
            (right-restmemlist (cdr rightstate))
            (leftstate (list2tree right-restmemlist (cdr depth) decorator))
            (lefttree (car leftstate))
            (left-restmemlist (cdr leftstate)))
        (cons (cons lefttree righttree) left-restmemlist)))))



;;================================================================
;; Registers
;;================================================================
(defun-lazy reg-A  (r1 r2 r3 r4 r5 r6) r1)
(defun-lazy reg-B  (r1 r2 r3 r4 r5 r6) r2)
(defun-lazy reg-C  (r1 r2 r3 r4 r5 r6) r3)
(defun-lazy reg-D  (r1 r2 r3 r4 r5 r6) r4)
(defun-lazy reg-SP (r1 r2 r3 r4 r5 r6) r5)
(defun-lazy reg-BP (r1 r2 r3 r4 r5 r6) r6)
(defmacro-lazy cons6 (r1 r2 r3 r4 r5 r6)
  `(lambda (f) (f ,r1 ,r2 ,r3 ,r4 ,r5 ,r6)))

;; (def-lazy init-reg
;;   (cons 
;;     (cons
;;       (cons int-zero int-zero)
;;       (cons int-zero int-zero))
;;     (cons
;;       (cons int-zero int-zero)
;;       (cons int-zero int-zero))))

;; (def-lazy init-reg
;;   (cons6 int-zero int-zero int-zero int-zero int-zero int-zero))

;; (defmacro-lazy reg-read (reg regptr)
;;   `(,reg ,regptr))

;; (defmacro-lazy rr (reg regptr)
;;   `(reg-read ,reg ,regptr))

;; (defun-lazy reg-write (reg value regptr)
;;   (regptr
;;     (cons6  value         (rr reg reg-B) (rr reg reg-C) (rr reg reg-D) (rr reg reg-SP) (rr reg reg-BP))
;;     (cons6 (rr reg reg-A)  value         (rr reg reg-C) (rr reg reg-D) (rr reg reg-SP) (rr reg reg-BP))
;;     (cons6 (rr reg reg-A) (rr reg reg-B)  value         (rr reg reg-D) (rr reg reg-SP) (rr reg reg-BP))
;;     (cons6 (rr reg reg-A) (rr reg reg-B) (rr reg reg-C)  value         (rr reg reg-SP) (rr reg reg-BP))
;;     (cons6 (rr reg reg-A) (rr reg reg-B) (rr reg reg-C) (rr reg reg-D)  value          (rr reg reg-BP))
;;     (cons6 (rr reg reg-A) (rr reg reg-B) (rr reg reg-C) (rr reg reg-D) (rr reg reg-SP)  value         )))

(defun-lazy regptr2regaddr (regptr)
  (regptr
    (list nil nil nil)
    (list t nil nil)
    (list nil t nil)
    (list t t nil)
    (list nil nil t)
    (list t nil t)))

(defun-lazy reg-read (reg regptr)
  (lookup-tree reg (regptr2regaddr regptr)))

(defun-lazy reg-write (reg value regptr)
  (memory-write reg (regptr2regaddr regptr) value))

;;================================================================
;; Arithmetic
;;================================================================
(defrec-lazy invert (n)
  (if (isnil n)
    nil
    (cons (not (car n)) (invert (cdr n)))))

(defrec-lazy add-carry (n m carry)
  (cond ((isnil n)
          nil)
        (t
          (if (car n)
            (if (car m)
              (cons carry       (add-carry (cdr n) (cdr m) t))
              (cons (not carry) (add-carry (cdr n) (cdr m) carry)))
            (if (car m)
              (cons (not carry) (add-carry (cdr n) (cdr m) carry))
              (cons carry       (add-carry (cdr n) (cdr m) nil)))))))

(defmacro-lazy add (n m)
  `(add-carry ,n ,m nil))

(defmacro-lazy sub (n m)
  `(add-carry ,n (invert ,m) t))

(defrec-lazy iszero-bit (n)
  (cond ((isnil n)
          t)
        ((car n)
          nil)
        (t
          (iszero-bit (cdr n)))))

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

(defun-lazy cmp (n m enum-cmp)
  ((cmp* (reverse n) (reverse m))
    (enum-cmp t nil nil nil t t)
    (enum-cmp nil t t nil t nil)
    (enum-cmp nil t nil t nil t)))

;;================================================================
;; I/O
;;================================================================
(def-lazy powerlist
  ((letrec-lazy powerlist (n bits)
    (cond ((isnil bits)
            nil)
          (t
            (cons n (powerlist (+ n n) (cdr bits))))))
    1 (take 8 (inflist t))))

(def-lazy revpowerlist
  (reverse powerlist))

(defrec-lazy bit2int* (n powerlist)
  (cond ((isnil powerlist)
          0)
        (t
          (if (car n)
            (+ (car powerlist) (bit2int* (cdr n) (cdr powerlist)))
            (bit2int* (cdr n) (cdr powerlist))))))

(defmacro-lazy bit2int (n)
  `(bit2int* ,n powerlist))

(defrec-lazy int2bit* (n revpowerlist)
  (cond ((isnil revpowerlist)
          nil)
        ((iszero n)
          (cons nil (int2bit* n (cdr revpowerlist))))
        (t
          (if (<= (car revpowerlist) n)
            (cons t   (int2bit* (- n (car revpowerlist)) (cdr revpowerlist)))
            (cons nil (int2bit* n (cdr revpowerlist)))))))

(defmacro-lazy int2bit (n)
  `(append-list (reverse (int2bit* ,n revpowerlist)) (take 16 (inflist nil))))

(defrec-lazy append-list (l item)
  (if (isnil l) item (cons (car l) (append-list (cdr l) item))))


;;================================================================
;; Instructions
;;================================================================
(defun-lazy inst-io-int  (i1 i2 i3 i4 i5 i6 i7 i8 i9) i1)
(defun-lazy inst-sub     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i2)
(defun-lazy inst-cmp     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i3)
(defun-lazy inst-load    (i1 i2 i3 i4 i5 i6 i7 i8 i9) i4)
(defun-lazy inst-jumpcmp (i1 i2 i3 i4 i5 i6 i7 i8 i9) i5)
(defun-lazy inst-jmp     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i6)
(defun-lazy inst-mov     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i7)
(defun-lazy inst-store   (i1 i2 i3 i4 i5 i6 i7 i8 i9) i8)
(defun-lazy inst-add     (i1 i2 i3 i4 i5 i6 i7 i8 i9) i9)

(defun-lazy cmp-eq (x1 x2 x3 x4 x5 x6) x1)
(defun-lazy cmp-ne (x1 x2 x3 x4 x5 x6) x2)
(defun-lazy cmp-lt (x1 x2 x3 x4 x5 x6) x3)
(defun-lazy cmp-gt (x1 x2 x3 x4 x5 x6) x4)
(defun-lazy cmp-le (x1 x2 x3 x4 x5 x6) x5)
(defun-lazy cmp-ge (x1 x2 x3 x4 x5 x6) x6)

(defun-lazy io-int-exit (x1 x2 x3) x1)
(defun-lazy io-int-getc (x1 x2 x3) x2)
(defun-lazy io-int-putc (x1 x2 x3) x3)

(defmacro-lazy car4-1 (f) `(,f (lambda (x1 x2 x3 x4) x1)))
(defmacro-lazy car4-2 (f) `(,f (lambda (x1 x2 x3 x4) x2)))
(defmacro-lazy car4-3 (f) `(,f (lambda (x1 x2 x3 x4) x3)))
(defmacro-lazy car4-4 (f) `(,f (lambda (x1 x2 x3 x4) x4)))
(defmacro-lazy cons4 (x1 x2 x3 x4)
  `(lambda (f) (f ,x1 ,x2 ,x3 ,x4)))


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
  (cond ((isnil curblock)
          SYS-STRING-TERM)
        (t
          ;; Prevent frequently used functions from being inlined every time
          (let ((lookup-tree lookup-tree)
                (memory-write memory-write)
                (reverse-helper reverse-helper)
                (expand-prog-at (lambda (pc) (flatten nil (lookup-tree progtree (reverse-helper pc nil)))))
                (powerlist powerlist)
                (add-carry add-carry)
                (cmp cmp)
                (regptr2regaddr regptr2regaddr)
                (reg-read reg-read)
                (curinst (car curblock))
                (*src (car4-3 curinst))
                (src (if (car4-2 curinst) *src (reg-read reg *src)))
                (*dst (car4-4 curinst))
                (nextblock (cdr curblock))
                (eval-reg-write
                  (lambda (src dst)
                    (eval (reg-write reg src dst) memory progtree stdin nextblock))))
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
                (cond ((isnil stdin)
                        (eval-reg-write int-zero *src))
                      (t
                        (eval
                          (reg-write reg (int2bit (car stdin)) *src)
                          memory progtree (cdr stdin) nextblock)))
                ;; putc
                (cons (bit2int src) (eval reg memory progtree stdin nextblock)))

              ;; ==== inst-sub ====
              ;; Instruction structure: (cons4 inst-store [src-isimm] [src] [*dst])
              (eval-reg-write
                (sub (reg-read reg *dst) src)
                *dst)

              ;; ==== inst-cmp ====
              ;; Instruction structure: (cons4 inst-cmp [src-isimm] [src] (cons [emum-cmp] [dst]))
              (let ((*dst-cmp (cdr *dst))
                    (cmp-result (cmp (reg-read reg *dst-cmp) src (car *dst))))
                (eval-reg-write
                  (if cmp-result (cons t (cdr int-zero)) int-zero)
                  *dst-cmp))

              ;; ==== inst-load ====
              ;; Instruction structure:: (cons4 inst-load [src-isimm] [src] [*dst])
              (eval-reg-write
                (let ((m (lookup-tree memory (reverse-helper src nil))))
                  (if (isnil m)
                    int-zero
                    m))
                *dst)

              ;; ==== inst-jumpcmp ====
              ;; Instruction structure: (cons4 inst-jumpcmp [src-isimm] [src] (cons4 [enum-cmp] [*dst] [jmp-isimm] [jmp]))
              (let ((*jmp (car4-4 *dst))
                    (jmp (if (car4-3 *dst) *jmp (reg-read reg *jmp))))
                (eval reg memory progtree stdin
                  (if (cmp (reg-read reg (car4-2 *dst)) src (car4-1 *dst))
                    (expand-prog-at jmp)
                    nextblock)))

              ;; ==== inst-jmp ====
              ;; Instruction structure:: (cons4 inst-jmp [jmp-isimm] [jmp] _)
              (eval reg memory progtree stdin (expand-prog-at src))

              ;; ==== inst-mov ====
              ;; Instruction structure:: (cons4 inst-mov [src-isimm] [src] [dst-memory])
              (eval-reg-write src *dst)

              ;; ==== inst-store ====
              ;; Instruction structure: (cons4 inst-store [dst-isimm] [dst-memory] [source])
              ;; Note that the destination is stored in the variable *src
              (eval reg (memory-write memory (reverse-helper src nil) (reg-read reg *dst)) progtree stdin nextblock)

              ;; ==== inst-add ====
              ;; Instruction structure: (cons4 inst-store [src-isimm] [src] [*dst])
              (eval-reg-write (add src (reg-read reg *dst)) *dst))))))


(defun-lazy main (memlist proglist stdin)
  (let ((list2tree list2tree)
        (take take)
        (int-zero int-zero))
    (eval
      (car (list2tree proglist (list t t t) (lambda (x) x)))
      (car (list2tree memlist int-zero car*))
      (car (list2tree proglist int-zero (lambda (x) x)))
      stdin
      (list
       (cons4 inst-jmp t int-zero nil)))))
