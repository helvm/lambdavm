# LambdaVM - A Programmable Virtual CPU Written as an Untyped Lambda Calculus Term
LambdaVM is a programmable virtual CPU written as a closed untyped lambda calculus term.
It supports an extended version of the [ELVM](https://github.com/shinh/elvm) architecture written by [Shinichiro Hamaji](https://github.com/shinh).
LambdaVM supports 8 instructions, and has an arbitrarily configurable ROM/RAM address size and word size, and an arbitrarily configurable number of registers.
Despite its rather rich capability, its lambda term is quite small. Here is its entire lambda term written in plaintext:

```text
LambdaVM = \x.\y.\z.\a.\b.((\c.((\d.((\e.((\f.((\g.((\h.(a ((\i.(i (d (\j.\k.(k 
(\l.\m.\n.\o.(o k (j m))) k)) a) (\j.(i z (d (\k.\l.\m.\n.\o.\p.((\q.((\r.((\s.(
n (\t.\u.\v.\w.v) (\t.t) (\t.\u.\v.u) (\t.\u.u) (o (\t.\u.\v.(o (k l m) p)) o) (
n (\t.\u.((\v.(t (\w.\A.\B.((\C.(A (C B) (s B C))) (\C.\D.(w (D ((\E.(m (\F.\G.\
H.(E (y (\I.\J.(J (\K.\L.K) I)) F) G)) (E c m))) (\E.\F.(r B E (k l F u o)))) (\
E.(E (y (\F.(F (\G.\H.H))) C) (v p))) A) (D (\E.\F.\G.\H.((\I.(F (I G) (s G I)))
 (s H (\I.\J.(E (e I C) (q J) (v p))))))) (D (\E.\F.((\G.(f (\H.\I.I) (E (s F e 
C)) G G (\H.(r F)))) c)) v) (q C) (h l C (r D) v) (s D (g l C) k m u o p) (D (\E
.\F.(s E (f F F) C (\G.(r E)))) v) (r D C v))))))) (k l m u o)))))) (h p))) (g p
))) (\q.(h j q (\r.(r (k l m) p))))))))))) (\i.\j.(d (\k.\l.\m.\n.(l (\o.\p.\q.(
m (\r.\s.\t.(k l s (\u.\v.(k v s (\w.(n (\A.(A u w)))))))) (l n))) (n l l))) i c
 (\k.\l.(j k)))) b) (\i.\j.j))) (d (\h.\i.\j.\k.(i (\l.\m.\n.(j (\o.\p.\q.(o (h 
l) (h m) p k)) (k i))) (k c)))))) (d (\g.\h.\i.\j.\k.(i (\l.\m.\n.((\o.(h (\p.\q
.\r.(l (h o) (o q p))) (o (\p.\q.q) (\p.\q.q)))) (\o.(g o m j (\p.\q.(l (k (\r.(
r p q))) (k (\r.(r q p))))))))) (k j)))))) (d (\f.\g.\h.\i.\j.\k.(i (\l.\m.\n.(j
 (\o.\p.(f g h m p (\q.\r.((\s.((\t.((\u.((\v.(t s q (v (\w.\A.w)) (v (\w.\A.A))
)) (t q (q (\v.\w.w) (\v.\w.v)) (u (\v.\w.v)) (u (\v.\w.w))))) (\u.\v.(k v (\w.(
w u r)))))) (\t.\u.(l (s t u) (s u t))))) (h o (o (\s.\t.t) (\s.\t.s))))))))) (k
 g i)))))) (d (\e.\f.\g.(f (\h.\i.\j.(g (\k.\l.((\m.(h (k m (\n.\o.\p.o)) (k (\n
.\o.\p.p) m))) (e i l))))) (\h.\i.\j.h)))))) (\d.((\e.(d (e e))) (\e.(d (e e))))
))) ((\c.(y c (x c (\d.\e.e)))) (\c.\d.(d (\e.\f.e) c))))
```

Shown here is a lambda calculus term featuring a RAM unit with 8 instructions including I/O and memory operations.

You can hand-assemble programs for LambdaVM to write lambda calculus programs in an imperative assembly language as described later.
Compiled lambda calculus programs can be run on the terminal using various lambda calculus interpreters, including:

- SectorLambda, the [521-byte lambda calculus interpreter](https://justine.lol/lambda/) written by Justine Tunney
- The [IOCCC](https://www.ioccc.org/) 2012 ["Most functional"](https://www.ioccc.org/2012/tromp/hint.html) interpreter written by John Tromp
  (the [source](https://www.ioccc.org/2012/tromp/tromp.c) is in the shape of a λ)
- Universal Lambda interpreter [clamb](https://github.com/irori/clamb) and Lazy K interpreter [lazyk](https://github.com/irori/lazyk) written by Kunihiko Sakamoto

I have integrated LambdaVM into ELVM to implement ELVM's lambda calculus backend.
Using this backend, you can even compile interactive C code to LambdaVM's assembly.
Since ELVM implements its [own libc](https://github.com/shinh/elvm/tree/master/libc), you can even `#include <stdio.h>` and use library functions such as `printf` and `scanf`.
Please see the documentation for ELVM for details.

Various designs for LambdaVM are borrowed from [Kunihiko Sakamoto](https://github.com/irori)'s [UnlambdaVM](https://irori.hatenablog.com/entry/elvm-unlambda-part2) (in Japanese), with many modifications. Details are described later.

LambdaVM is built with [LambdaCraft](https://github.com/woodrush/lambdacraft), a Common Lisp DSL that I wrote for building large lambda calculus programs, also used to build [LambdaLisp](https://github.com/woodrush/lambdalisp).


## Lambda Calculus as a Programming Language
Lambda calculus terms can be interpreted as programs, by interpreting it as a program that takes an input string and returns an output string.
Characters and bytes are encoded as a list of bits with $0 = \lambda x. \lambda y.x$, $1 = \lambda x. \lambda y.y$,
and lists are encoded in the [Scott encoding](https://en.wikipedia.org/wiki/Mogensen%E2%80%93Scott_encoding) with ${\rm cons} = \lambda x.\lambda y.\lambda f.(f x y)$, ${\rm nil} = \lambda x.\lambda y.y$.
This way, _everything_ in the computation process, even including integers, is expressed as pure lambda terms,
without the need of introducing any non-lambda type object whatsoever.

Various lambda calculus interpreters automatically handle this I/O format so that it runs on the terminal - standard input is encoded into lambda terms, and the output lambda term is decoded and shown on the terminal.
Using these interpreters, lambda calculus programs can be run on the terminal just like any other terminal utility with I/O.

A thorough explanation of programming in lambda calculus is described in [my blog post](https://woodrush.github.io/blog/lambdalisp.html) about [LambdaLisp](https://github.com/woodrush/lambdalisp), a Lisp interpreter written as an untyped lambda calculus term.


## Features
- Instruction set:
  - `mov` `load` `store` `addsub` `cmp` `jmpcmp` `jmp` `putchar` `getchar` `exit`
- ROM/RAM address size and word size:
  - Pre-configurable to an arbitrary integer
- I/O bit size:
  - Pre-configurable to an arbitrary integer
- Registers:
  - Word size is pre-configurable to an arbitrary integer
  - Number of registers is arbitrarily pre-configurable


## Specifications
LambdaVM is written as the following lambda calculus term:

$$
{\rm LambdaVM} = \lambda.{\rm iobitsize} ~ \lambda.{\rm suppbitsize} ~ \lambda.{\rm proglist} ~ \lambda.{\rm memlist} ~ \lambda.{\rm stdin} ~ \cdots
$$

- The first 2 arguments ${\rm iobitsize}$ and ${\rm suppbitsize}$ are configuration parameters specifying the CPU's I/O word size and RAM word size.
- ${\rm proglist}$ represents the assembly listing to be executed.
- ${\rm memlist}$ represents the memory initialization state. Unspecified memory regions are initialized to 0.
- ${\rm stdin}$ is the input string provided by the interpreter.

By applying the first 4 arguments except ${\rm stdin}$ to ${\rm LambdaVM}$, the combined lambda term
$({\rm LambdaVM} ~ {\rm iobitsize} ~ {\rm suppbitsize} ~ {\rm proglist} ~ {\rm memlist})$ behaves as a lambda calculus program that accepts a string
${\rm stdin}$, processes it, and returns some string.


### Implementation Design
Various designs for LambdaVM are borrowed from [Kunihiko Sakamoto](https://github.com/irori)'s [UnlambdaVM](https://irori.hatenablog.com/entry/elvm-unlambda-part2) (in Japanese):

- Using a binary tree structure to represent the RAM
- Using a list of lists of instructions to represent the program

LambdaVM has the following differences:
- While Unlambda is a strictly evaluated language, LambdaVM assumes a lazily evaluated language.
  While UnlambdaVM is written in direct style using function applications to mutate the VM's global state,
  LambdaVM is written using continuation-passing style to handle monadic I/O.
- The binary tree structure is modified so that an empty tree can be initialized with `nil = \x.\y.y`.


### iobitsize and suppbitsize
`iobitsize` and `suppbitsize` are integers encoded as lambda terms in the [Church encoding](https://en.wikipedia.org/wiki/Church_encoding).

`iobitsize` specifies the number of bits used for the input string.
In the [IOCCC](https://www.ioccc.org/) 2012 ["Most functional"](https://www.ioccc.org/2012/tromp/hint.html) interpreter,
`iobitsize == 8` since it uses 8 bits for encoding the I/O.

`suppbitsize` represents the additional number of bits added to `iobitsize` to make the machine's RAM and register word size.
The word size becomes `iobitsize + suppbitsize`.

In ELVM, the machine word size is 24 and the I/O bit size is 8, so `iobitsize` and `suppbitsize` are set to 8 and 16, respectively.

### proglist
`proglist` is represented as a list of lists, where each sublist is a _tag_ containing a list of instructions.
The instruction format is described later.
The beginning of each list represents a tag that can be jumped to using the `jmp` or `jmpcmp` instructions.
When the `jmp` or `jmpcmp` instruction is run, the program proceeds to the beginning of the specified tag.

### memlist
`memlist` is represented as a list of N-bit unsigned integers with the machine's word size, where each integer is represented as a list of bits with
$0 = \lambda x. \lambda y.x$ and $1 = \lambda x. \lambda y.y$.
The elements of each list are assigned to contiguous RAM addresses startting from the address zero.
The rest of the memory is initiliazed with the integer zero.

### stdin
This variable is supplied by the interpreter.
The input is expected to be a list of characters, where each character is a list of bits of length `iobitsize`.
This incoming character is appended with `suppbitsize` bits of 0.


## Hand-Assembling Your Own LambdaVM Programs
You can hand-assemble your own LambdaVM programs using [LambdaCraft](https://github.com/woodrush/lambdacraft),
a Common Lisp DSL I wrote for building lambda calculus programs, also used to build [LambdaLisp](https://github.com/woodrush/lambdalisp).

The [examples](https://github.com/woodrush/lambdavm/tree/main/examples) directory in this repo contains 3 example LambdaVM assembly programs:

- [fizzbuzz.cl](https://github.com/woodrush/lambdavm/blob/main/examples/fizzbuzz.cl): Prints the FizzBuzz sequence in unary.
- [rot13.cl](https://github.com/woodrush/lambdavm/blob/main/examples/rot13.cl): Encodes/decodes standard input to/from the [ROT13](https://en.wikipedia.org/wiki/ROT13) cipher.
- [yes.cl](https://github.com/woodrush/lambdavm/blob/main/examples/yes.cl): The Unix `yes` command, printing infinite lines of `y`.

Here is what the beginning of the assembly listing for rot13.cl looks like:

```lisp
(def-lazy asm (list
  ;; Initialization (PC == 0)
  (list
    ;; Store 26/2 = 13 at reg-B
    (mov reg-B "N")
    (sub reg-B "A")
  )
  ;; tag-main (PC == 1)
  (list
    (getc reg-A)

    ;; Exit at EOF
    (jmpcmp reg-A == EOF -> tag-exit)

    ;; "a" <= reg-A < "n" : add 13
    (mov reg-C reg-A)
    (cmp reg-C >= "a")
    (mov reg-D reg-A)
    (cmp reg-D < "n")
    (add reg-C reg-D)
    (jmpcmp reg-C == int-2 -> tag-plus13)
...
```

As shown here, the assembly is written as Common Lisp macros.
These listings can be compiled by running *.cl on a Common Lisp interpreter such as SBCL.

Since these programs are based on LambdaCraft and LambdaCraft runs on LambdaLisp,
it is expected that these programs run on LambdaLisp as well, although it takes a lot of time compared to fast interpreters such as SBCL.


## Implementation Details
Please see [details.md](details.md).


## Credits
LambdaVM was written by Hikaru Ikuta, inspired by [Kunihiko Sakamoto](https://github.com/irori)'s [UnlambdaVM](https://irori.hatenablog.com/entry/elvm-unlambda-part2) (in Japanese).
The instruction set for LambdaVM is based on and is extended from the [ELVM](https://github.com/shinh/elvm) architecture written by [Shinichiro Hamaji](https://github.com/shinh).
LambdaVM is written using [LambdaCraft](https://github.com/woodrush/lambdacraft) written by Hikaru Ikuta.
