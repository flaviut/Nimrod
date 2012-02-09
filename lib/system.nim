#
#
#            Nimrod's Runtime Library
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## The compiler depends on the System module to work properly and the System
## module depends on the compiler. Most of the routines listed here use
## special compiler magic.
## Each module implicitly imports the System module; it must not be listed
## explicitly. Because of this there cannot be a user-defined module named
## ``system``.

type
  int* {.magic: Int.} ## default integer type; bitwidth depends on
                      ## architecture, but is always the same as a pointer
  int8* {.magic: Int8.} ## signed 8 bit integer type
  int16* {.magic: Int16.} ## signed 16 bit integer type
  int32* {.magic: Int32.} ## signed 32 bit integer type
  int64* {.magic: Int64.} ## signed 64 bit integer type
  float* {.magic: Float.} ## default floating point type
  float32* {.magic: Float32.} ## 32 bit floating point type
  float64* {.magic: Float64.} ## 64 bit floating point type
type # we need to start a new type section here, so that ``0`` can have a type
  bool* {.magic: Bool.} = enum ## built-in boolean type
    false = 0, true = 1

type
  char* {.magic: Char.} ## built-in 8 bit character type (unsigned)
  string* {.magic: String.} ## built-in string type
  cstring* {.magic: Cstring.} ## built-in cstring (*compatible string*) type
  pointer* {.magic: Pointer.} ## built-in pointer type

const
  on* = true    ## alias for ``true``
  off* = false  ## alias for ``false``

{.push hints: off.}

type
  Ordinal* {.magic: Ordinal.}[T]
  `nil` {.magic: "Nil".}
  expr* {.magic: Expr.} ## meta type to denote an expression (for templates)
  stmt* {.magic: Stmt.} ## meta type to denote a statement (for templates)
  typeDesc* {.magic: TypeDesc.} ## meta type to denote
                                ## a type description (for templates)
  void* {.magic: "VoidType".}  ## meta type to denote the absense of any type

proc defined*[T](x: T): bool {.magic: "Defined", noSideEffect.}
  ## Special compile-time procedure that checks whether `x` is
  ## defined. `x` has to be an identifier or a qualified identifier.
  ## This can be used to check whether a library provides a certain
  ## feature or not:
  ##
  ## .. code-block:: Nimrod
  ##   when not defined(strutils.toUpper):
  ##     # provide our own toUpper proc here, because strutils is
  ##     # missing it.

proc definedInScope*[T](x: T): bool {.
  magic: "DefinedInScope", noSideEffect.}
  ## Special compile-time procedure that checks whether `x` is
  ## defined in the current scope. `x` has to be an identifier.

proc `not` *(x: bool): bool {.magic: "Not", noSideEffect.}
  ## Boolean not; returns true iff ``x == false``.

proc `and`*(x, y: bool): bool {.magic: "And", noSideEffect.}
  ## Boolean ``and``; returns true iff ``x == y == true``.
  ## Evaluation is lazy: if ``x`` is false,
  ## ``y`` will not even be evaluated.
proc `or`*(x, y: bool): bool {.magic: "Or", noSideEffect.}
  ## Boolean ``or``; returns true iff ``not (not x and not y)``.
  ## Evaluation is lazy: if ``x`` is true,
  ## ``y`` will not even be evaluated.
proc `xor`*(x, y: bool): bool {.magic: "Xor", noSideEffect.}
  ## Boolean `exclusive or`; returns true iff ``x != y``.

proc new*[T](a: var ref T) {.magic: "New", noSideEffect.}
  ## creates a new object of type ``T`` and returns a safe (traced)
  ## reference to it in ``a``.

proc internalNew*[T](a: var ref T) {.magic: "New", noSideEffect.}
  ## leaked implementation detail. Do not use.

proc new*[T](a: var ref T, finalizer: proc (x: ref T)) {.
  magic: "NewFinalize", noSideEffect.}
  ## creates a new object of type ``T`` and returns a safe (traced)
  ## reference to it in ``a``. When the garbage collector frees the object,
  ## `finalizer` is called. The `finalizer` may not keep a reference to the
  ## object pointed to by `x`. The `finalizer` cannot prevent the GC from
  ## freeing the object. Note: The `finalizer` refers to the type `T`, not to
  ## the object! This means that for each object of type `T` the finalizer
  ## will be called!
  
proc reset*[T](obj: var T) {.magic: "Reset", noSideEffect.}
  ## resets an object `obj` to its initial (binary zero) value. This needs to
  ## be called before any possible `object branch transition`:idx:.

# for low and high the return type T may not be correct, but
# we handle that with compiler magic in SemLowHigh()
proc high*[T](x: T): T {.magic: "High", noSideEffect.}
  ## returns the highest possible index of an array, a sequence, a string or
  ## the highest possible value of an ordinal value `x`. As a special
  ## semantic rule, `x` may also be a type identifier.

proc low*[T](x: T): T {.magic: "Low", noSideEffect.}
  ## returns the lowest possible index of an array, a sequence, a string or
  ## the lowest possible value of an ordinal value `x`. As a special
  ## semantic rule, `x` may also be a type identifier.

type
  range*{.magic: "Range".} [T] ## Generic type to construct range types.
  array*{.magic: "Array".}[I, T]  ## Generic type to construct
                                  ## fixed-length arrays.
  openarray*{.magic: "OpenArray".}[T]  ## Generic type to construct open arrays.
                                       ## Open arrays are implemented as a
                                       ## pointer to the array data and a
                                       ## length field.
  seq*{.magic: "Seq".}[T]  ## Generic type to construct sequences.
  set*{.magic: "Set".}[T]  ## Generic type to construct bit sets.

type
  TSlice* {.final, pure.}[T] = object ## builtin slice type
    a*, b*: T                         ## the bounds

proc `..`*[T](a, b: T): TSlice[T] {.noSideEffect, inline.} =
  ## `slice`:idx: operator that constructs an interval ``[a, b]``, both `a`
  ## and `b` are inclusive. Slices can also be used in the set constructor
  ## and in ordinal case statements, but then they are special-cased by the
  ## compiler.
  result.a = a
  result.b = b

proc `..`*[T](b: T): TSlice[T] {.noSideEffect, inline.} =
  ## `slice`:idx: operator that constructs an interval ``[default(T), b]``
  result.b = b

proc contains*[T](s: TSlice[T], value: T): bool {.noSideEffect, inline.} = 
  result = value >= s.a and value <= s.b

when not defined(EcmaScript) and not defined(NimrodVM):
  type
    TGenericSeq {.compilerproc, pure.} = object
      len, reserved: int
    PGenericSeq {.exportc.} = ptr TGenericSeq
    # len and space without counting the terminating zero:
    NimStringDesc {.compilerproc, final.} = object of TGenericSeq
      data: array[0..100_000_000, char]
    NimString = ptr NimStringDesc
    
  template space(s: PGenericSeq): int = s.reserved and not seqShallowFlag

  include "system/hti"

type
  Byte* = Int8 ## this is an alias for ``int8``, that is a signed
               ## int 8 bits wide.

  Natural* = range[0..high(int)]
    ## is an int type ranging from zero to the maximum value
    ## of an int. This type is often useful for documentation and debugging.

  Positive* = range[1..high(int)]
    ## is an int type ranging from one to the maximum value
    ## of an int. This type is often useful for documentation and debugging.

  TObject* {.exportc: "TNimObject".} =
    object ## the root of Nimrod's object hierarchy. Objects should
           ## inherit from TObject or one of its descendants. However,
           ## objects that have no ancestor are allowed.
  PObject* = ref TObject ## reference to TObject

  E_Base* {.compilerproc.} = object of TObject ## base exception class;
                                               ## each exception has to
                                               ## inherit from `E_Base`.
    parent: ref E_Base        ## parent exception (can be used as a stack)
    name: cstring             ## The exception's name is its Nimrod identifier.
                              ## This field is filled automatically in the
                              ## ``raise`` statement.
    msg* {.exportc: "message".}: string ## the exception's message. Not
                                        ## providing an exception message 
                                        ## is bad style.

  EAsynch* = object of E_Base ## Abstract exception class for
                              ## *asynchronous exceptions* (interrupts).
                              ## This is rarely needed: Most
                              ## exception types inherit from `ESynch`
  ESynch* = object of E_Base  ## Abstract exception class for
                              ## *synchronous exceptions*. Most exceptions
                              ## should be inherited (directly or indirectly)
                              ## from ESynch.
  ESystem* = object of ESynch ## Abstract class for exceptions that the runtime
                              ## system raises.
  EIO* = object of ESystem    ## raised if an IO error occured.
  EOS* = object of ESystem    ## raised if an operating system service failed.
  EInvalidLibrary* = object of EOS ## raised if a dynamic library
                                   ## could not be loaded.
  EResourceExhausted* = object of ESystem ## raised if a resource request
                                           ## could not be fullfilled.
  EArithmetic* = object of ESynch       ## raised if any kind of arithmetic
                                        ## error occured.
  EDivByZero* {.compilerproc.} =
    object of EArithmetic ## is the exception class for integer divide-by-zero
                          ## errors.
  EOverflow* {.compilerproc.} =
    object of EArithmetic  ## is the exception class for integer calculations
                           ## whose results are too large to fit in the
                           ## provided bits.

  EAccessViolation* {.compilerproc.} =
    object of ESynch ## the exception class for invalid memory access errors

  EAssertionFailed* {.compilerproc.} =
    object of ESynch  ## is the exception class for Assert
                      ## procedures that is raised if the
                      ## assertion proves wrong

  EControlC* = object of EAsynch        ## is the exception class for Ctrl+C
                                        ## key presses in console applications.

  EInvalidValue* = object of ESynch     ## is the exception class for string
                                        ## and object conversion errors.
  EInvalidKey* = object of EInvalidValue ## is the exception class if a key
                                         ## cannot be found in a table.

  EOutOfMemory* = object of ESystem     ## is the exception class for
                                        ## unsuccessful attempts to allocate
                                        ## memory.

  EInvalidIndex* = object of ESynch     ## is raised if an array index is out
                                        ## of bounds.
  EInvalidField* = object of ESynch     ## is raised if a record field is not
                                        ## accessible because its dicriminant's
                                        ## value does not fit.

  EOutOfRange* = object of ESynch       ## is raised if a range check error
                                        ## occured.

  EStackOverflow* = object of ESystem   ## is raised if the hardware stack
                                        ## used for subroutine calls overflowed.

  ENoExceptionToReraise* = object of ESynch ## is raised if there is no
                                            ## exception to reraise.

  EInvalidObjectAssignment* =
    object of ESynch ## is raised if an object gets assigned to its
                     ## parent's object.

  EInvalidObjectConversion* =
    object of ESynch ## is raised if an object is converted to an incompatible
                     ## object type.

  EFloatingPoint* = object of ESynch ## base class for floating point exceptions
  EFloatInvalidOp* {.compilerproc.} = 
    object of EFloatingPoint ## Invalid operation according to IEEE: Raised by 
                             ## 0.0/0.0, for example.
  EFloatDivByZero* {.compilerproc.} = 
    object of EFloatingPoint ## Division by zero. Divisor is zero and dividend 
                             ## is a finite nonzero number.
  EFloatOverflow* {.compilerproc.} = 
    object of EFloatingPoint ## Overflow. Operation produces a result 
                             ## that exceeds the range of the exponent
  EFloatUnderflow* {.compilerproc.} = 
    object of EFloatingPoint ## Underflow. Operation produces a result 
                             ## that is too small to be represented as 
                             ## a normal number
  EFloatInexact* {.compilerproc.} = 
    object of EFloatingPoint ## Inexact. Operation produces a result
                             ## that cannot be represented with infinite
                             ## precision -- for example, 2.0 / 3.0, log(1.1) 
                             ## NOTE: Nimrod currently does not detect these!
  EDeadThread* =
    object of ESynch ## is raised if it is attempted to send a message to a
                     ## dead thread.
                     
  TResult* = enum Failure, Success

proc sizeof*[T](x: T): natural {.magic: "SizeOf", noSideEffect.}
  ## returns the size of ``x`` in bytes. Since this is a low-level proc,
  ## its usage is discouraged - using ``new`` for the most cases suffices
  ## that one never needs to know ``x``'s size. As a special semantic rule,
  ## ``x`` may also be a type identifier (``sizeof(int)`` is valid).

proc `<`*[T](x: ordinal[T]): T {.magic: "UnaryLt", noSideEffect.}
  ## unary ``<`` that can be used for nice looking excluding ranges:
  ## 
  ## .. code-block:: nimrod
  ##   for i in 0 .. <10: echo i
  ##
  ## Semantically this is the same as ``pred``. 

proc succ*[T](x: ordinal[T], y = 1): T {.magic: "Succ", noSideEffect.}
  ## returns the ``y``-th successor of the value ``x``. ``T`` has to be
  ## an ordinal type. If such a value does not exist, ``EOutOfRange`` is raised
  ## or a compile time error occurs.

proc pred*[T](x: ordinal[T], y = 1): T {.magic: "Pred", noSideEffect.}
  ## returns the ``y``-th predecessor of the value ``x``. ``T`` has to be
  ## an ordinal type. If such a value does not exist, ``EOutOfRange`` is raised
  ## or a compile time error occurs.

proc inc*[T](x: var ordinal[T], y = 1) {.magic: "Inc", noSideEffect.}
  ## increments the ordinal ``x`` by ``y``. If such a value does not
  ## exist, ``EOutOfRange`` is raised or a compile time error occurs. This is a
  ## short notation for: ``x = succ(x, y)``.

proc dec*[T](x: var ordinal[T], y = 1) {.magic: "Dec", noSideEffect.}
  ## decrements the ordinal ``x`` by ``y``. If such a value does not
  ## exist, ``EOutOfRange`` is raised or a compile time error occurs. This is a
  ## short notation for: ``x = pred(x, y)``.
  
proc newSeq*[T](s: var seq[T], len: int) {.magic: "NewSeq", noSideEffect.}
  ## creates a new sequence of type ``seq[T]`` with length ``len``.
  ## This is equivalent to ``s = @[]; setlen(s, len)``, but more
  ## efficient since no reallocation is needed.

proc len*[T: openArray](x: T): int {.magic: "LengthOpenArray", noSideEffect.}
proc len*(x: string): int {.magic: "LengthStr", noSideEffect.}
proc len*(x: cstring): int {.magic: "LengthStr", noSideEffect.}
proc len*[I, T](x: array[I, T]): int {.magic: "LengthArray", noSideEffect.}
proc len*[T](x: seq[T]): int {.magic: "LengthSeq", noSideEffect.}
  ## returns the length of an array, an openarray, a sequence or a string.
  ## This is rougly the same as ``high(T)-low(T)+1``, but its resulting type is
  ## always an int.

# set routines:
proc incl*[T](x: var set[T], y: T) {.magic: "Incl", noSideEffect.}
  ## includes element ``y`` to the set ``x``. This is the same as
  ## ``x = x + {y}``, but it might be more efficient.

proc excl*[T](x: var set[T], y: T) {.magic: "Excl", noSideEffect.}
  ## excludes element ``y`` to the set ``x``. This is the same as
  ## ``x = x - {y}``, but it might be more efficient.

proc card*[T](x: set[T]): int {.magic: "Card", noSideEffect.}
  ## returns the cardinality of the set ``x``, i.e. the number of elements
  ## in the set.

proc ord*[T](x: T): int {.magic: "Ord", noSideEffect.}
  ## returns the internal int value of an ordinal value ``x``.

proc chr*(u: range[0..255]): char {.magic: "Chr", noSideEffect.}
  ## converts an int in the range 0..255 to a character.

# --------------------------------------------------------------------------
# built-in operators

proc ze*(x: int8): int {.magic: "Ze8ToI", noSideEffect.}
  ## zero extends a smaller integer type to ``int``. This treats `x` as
  ## unsigned.
proc ze*(x: int16): int {.magic: "Ze16ToI", noSideEffect.}
  ## zero extends a smaller integer type to ``int``. This treats `x` as
  ## unsigned.

proc ze64*(x: int8): int64 {.magic: "Ze8ToI64", noSideEffect.}
  ## zero extends a smaller integer type to ``int64``. This treats `x` as
  ## unsigned.
proc ze64*(x: int16): int64 {.magic: "Ze16ToI64", noSideEffect.}
  ## zero extends a smaller integer type to ``int64``. This treats `x` as
  ## unsigned.

proc ze64*(x: int32): int64 {.magic: "Ze32ToI64", noSideEffect.}
  ## zero extends a smaller integer type to ``int64``. This treats `x` as
  ## unsigned.
proc ze64*(x: int): int64 {.magic: "ZeIToI64", noDecl, noSideEffect.}
  ## zero extends a smaller integer type to ``int64``. This treats `x` as
  ## unsigned. Does nothing if the size of an ``int`` is the same as ``int64``.
  ## (This is the case on 64 bit processors.)

proc toU8*(x: int): int8 {.magic: "ToU8", noSideEffect.}
  ## treats `x` as unsigned and converts it to a byte by taking the last 8 bits
  ## from `x`.
proc toU16*(x: int): int16 {.magic: "ToU16", noSideEffect.}
  ## treats `x` as unsigned and converts it to an ``int16`` by taking the last
  ## 16 bits from `x`.
proc toU32*(x: int64): int32 {.magic: "ToU32", noSideEffect.}
  ## treats `x` as unsigned and converts it to an ``int32`` by taking the
  ## last 32 bits from `x`.


# integer calculations:
proc `+` *(x: int): int {.magic: "UnaryPlusI", noSideEffect.}
proc `+` *(x: int8): int8 {.magic: "UnaryPlusI", noSideEffect.}
proc `+` *(x: int16): int16 {.magic: "UnaryPlusI", noSideEffect.}
proc `+` *(x: int32): int32 {.magic: "UnaryPlusI", noSideEffect.}
proc `+` *(x: int64): int64 {.magic: "UnaryPlusI64", noSideEffect.}
  ## Unary `+` operator for an integer. Has no effect.

proc `-` *(x: int): int {.magic: "UnaryMinusI", noSideEffect.}
proc `-` *(x: int8): int8 {.magic: "UnaryMinusI", noSideEffect.}
proc `-` *(x: int16): int16 {.magic: "UnaryMinusI", noSideEffect.}
proc `-` *(x: int32): int32 {.magic: "UnaryMinusI", noSideEffect.}
proc `-` *(x: int64): int64 {.magic: "UnaryMinusI64", noSideEffect.}
  ## Unary `-` operator for an integer. Negates `x`.

proc `not` *(x: int): int {.magic: "BitnotI", noSideEffect.}
proc `not` *(x: int8): int8 {.magic: "BitnotI", noSideEffect.}
proc `not` *(x: int16): int16 {.magic: "BitnotI", noSideEffect.}
proc `not` *(x: int32): int32 {.magic: "BitnotI", noSideEffect.}
proc `not` *(x: int64): int64 {.magic: "BitnotI64", noSideEffect.}
  ## computes the `bitwise complement` of the integer `x`.

proc `+` *(x, y: int): int {.magic: "AddI", noSideEffect.}
proc `+` *(x, y: int8): int8 {.magic: "AddI", noSideEffect.}
proc `+` *(x, y: int16): int16 {.magic: "AddI", noSideEffect.}
proc `+` *(x, y: int32): int32 {.magic: "AddI", noSideEffect.}
proc `+` *(x, y: int64): int64 {.magic: "AddI64", noSideEffect.}
  ## Binary `+` operator for an integer.

proc `-` *(x, y: int): int {.magic: "SubI", noSideEffect.}
proc `-` *(x, y: int8): int8 {.magic: "SubI", noSideEffect.}
proc `-` *(x, y: int16): int16 {.magic: "SubI", noSideEffect.}
proc `-` *(x, y: int32): int32 {.magic: "SubI", noSideEffect.}
proc `-` *(x, y: int64): int64 {.magic: "SubI64", noSideEffect.}
  ## Binary `-` operator for an integer.

proc `*` *(x, y: int): int {.magic: "MulI", noSideEffect.}
proc `*` *(x, y: int8): int8 {.magic: "MulI", noSideEffect.}
proc `*` *(x, y: int16): int16 {.magic: "MulI", noSideEffect.}
proc `*` *(x, y: int32): int32 {.magic: "MulI", noSideEffect.}
proc `*` *(x, y: int64): int64 {.magic: "MulI64", noSideEffect.}
  ## Binary `*` operator for an integer.

proc `div` *(x, y: int): int {.magic: "DivI", noSideEffect.}
proc `div` *(x, y: int8): int8 {.magic: "DivI", noSideEffect.}
proc `div` *(x, y: int16): int16 {.magic: "DivI", noSideEffect.}
proc `div` *(x, y: int32): int32 {.magic: "DivI", noSideEffect.}
proc `div` *(x, y: int64): int64 {.magic: "DivI64", noSideEffect.}
  ## computes the integer division. This is roughly the same as
  ## ``floor(x/y)``.

proc `mod` *(x, y: int): int {.magic: "ModI", noSideEffect.}
proc `mod` *(x, y: int8): int8 {.magic: "ModI", noSideEffect.}
proc `mod` *(x, y: int16): int16 {.magic: "ModI", noSideEffect.}
proc `mod` *(x, y: int32): int32 {.magic: "ModI", noSideEffect.}
proc `mod` *(x, y: int64): int64 {.magic: "ModI64", noSideEffect.}
  ## computes the integer modulo operation. This is the same as
  ## ``x - (x div y) * y``.

proc `shr` *(x, y: int): int {.magic: "ShrI", noSideEffect.}
proc `shr` *(x, y: int8): int8 {.magic: "ShrI", noSideEffect.}
proc `shr` *(x, y: int16): int16 {.magic: "ShrI", noSideEffect.}
proc `shr` *(x, y: int32): int32 {.magic: "ShrI", noSideEffect.}
proc `shr` *(x, y: int64): int64 {.magic: "ShrI64", noSideEffect.}
  ## computes the `shift right` operation of `x` and `y`.

proc `shl` *(x, y: int): int {.magic: "ShlI", noSideEffect.}
proc `shl` *(x, y: int8): int8 {.magic: "ShlI", noSideEffect.}
proc `shl` *(x, y: int16): int16 {.magic: "ShlI", noSideEffect.}
proc `shl` *(x, y: int32): int32 {.magic: "ShlI", noSideEffect.}
proc `shl` *(x, y: int64): int64 {.magic: "ShlI64", noSideEffect.}
  ## computes the `shift left` operation of `x` and `y`.

proc `and` *(x, y: int): int {.magic: "BitandI", noSideEffect.}
proc `and` *(x, y: int8): int8 {.magic: "BitandI", noSideEffect.}
proc `and` *(x, y: int16): int16 {.magic: "BitandI", noSideEffect.}
proc `and` *(x, y: int32): int32 {.magic: "BitandI", noSideEffect.}
proc `and` *(x, y: int64): int64 {.magic: "BitandI64", noSideEffect.}
  ## computes the `bitwise and` of numbers `x` and `y`.

proc `or` *(x, y: int): int {.magic: "BitorI", noSideEffect.}
proc `or` *(x, y: int8): int8 {.magic: "BitorI", noSideEffect.}
proc `or` *(x, y: int16): int16 {.magic: "BitorI", noSideEffect.}
proc `or` *(x, y: int32): int32 {.magic: "BitorI", noSideEffect.}
proc `or` *(x, y: int64): int64 {.magic: "BitorI64", noSideEffect.}
  ## computes the `bitwise or` of numbers `x` and `y`.

proc `xor` *(x, y: int): int {.magic: "BitxorI", noSideEffect.}
proc `xor` *(x, y: int8): int8 {.magic: "BitxorI", noSideEffect.}
proc `xor` *(x, y: int16): int16 {.magic: "BitxorI", noSideEffect.}
proc `xor` *(x, y: int32): int32 {.magic: "BitxorI", noSideEffect.}
proc `xor` *(x, y: int64): int64 {.magic: "BitxorI64", noSideEffect.}
  ## computes the `bitwise xor` of numbers `x` and `y`.

proc `==` *(x, y: int): bool {.magic: "EqI", noSideEffect.}
proc `==` *(x, y: int8): bool {.magic: "EqI", noSideEffect.}
proc `==` *(x, y: int16): bool {.magic: "EqI", noSideEffect.}
proc `==` *(x, y: int32): bool {.magic: "EqI", noSideEffect.}
proc `==` *(x, y: int64): bool {.magic: "EqI64", noSideEffect.}
  ## Compares two integers for equality.

proc `<=` *(x, y: int): bool {.magic: "LeI", noSideEffect.}
proc `<=` *(x, y: int8): bool {.magic: "LeI", noSideEffect.}
proc `<=` *(x, y: int16): bool {.magic: "LeI", noSideEffect.}
proc `<=` *(x, y: int32): bool {.magic: "LeI", noSideEffect.}
proc `<=` *(x, y: int64): bool {.magic: "LeI64", noSideEffect.}
  ## Returns true iff `x` is less than or equal to `y`.

proc `<` *(x, y: int): bool {.magic: "LtI", noSideEffect.}
proc `<` *(x, y: int8): bool {.magic: "LtI", noSideEffect.}
proc `<` *(x, y: int16): bool {.magic: "LtI", noSideEffect.}
proc `<` *(x, y: int32): bool {.magic: "LtI", noSideEffect.}
proc `<` *(x, y: int64): bool {.magic: "LtI64", noSideEffect.}
  ## Returns true iff `x` is less than `y`.

proc abs*(x: int): int {.magic: "AbsI", noSideEffect.}
proc abs*(x: int8): int8 {.magic: "AbsI", noSideEffect.}
proc abs*(x: int16): int16 {.magic: "AbsI", noSideEffect.}
proc abs*(x: int32): int32 {.magic: "AbsI", noSideEffect.}
proc abs*(x: int64): int64 {.magic: "AbsI64", noSideEffect.}
  ## returns the absolute value of `x`. If `x` is ``low(x)`` (that 
  ## is -MININT for its type), an overflow exception is thrown (if overflow
  ## checking is turned on).

proc `+%` *(x, y: int): int {.magic: "AddU", noSideEffect.}
proc `+%` *(x, y: int8): int8 {.magic: "AddU", noSideEffect.}
proc `+%` *(x, y: int16): int16 {.magic: "AddU", noSideEffect.}
proc `+%` *(x, y: int32): int32 {.magic: "AddU", noSideEffect.}
proc `+%` *(x, y: int64): int64 {.magic: "AddU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and adds them. The result is truncated to
  ## fit into the result. This implements modulo arithmetic. No overflow
  ## errors are possible.

proc `-%` *(x, y: int): int {.magic: "SubU", noSideEffect.}
proc `-%` *(x, y: int8): int8 {.magic: "SubU", noSideEffect.}
proc `-%` *(x, y: int16): int16 {.magic: "SubU", noSideEffect.}
proc `-%` *(x, y: int32): int32 {.magic: "SubU", noSideEffect.}
proc `-%` *(x, y: int64): int64 {.magic: "SubU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and subtracts them. The result is
  ## truncated to fit into the result. This implements modulo arithmetic.
  ## No overflow errors are possible.

proc `*%` *(x, y: int): int {.magic: "MulU", noSideEffect.}
proc `*%` *(x, y: int8): int8 {.magic: "MulU", noSideEffect.}
proc `*%` *(x, y: int16): int16 {.magic: "MulU", noSideEffect.}
proc `*%` *(x, y: int32): int32 {.magic: "MulU", noSideEffect.}
proc `*%` *(x, y: int64): int64 {.magic: "MulU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and multiplies them. The result is
  ## truncated to fit into the result. This implements modulo arithmetic.
  ## No overflow errors are possible.

proc `/%` *(x, y: int): int {.magic: "DivU", noSideEffect.}
proc `/%` *(x, y: int8): int8 {.magic: "DivU", noSideEffect.}
proc `/%` *(x, y: int16): int16 {.magic: "DivU", noSideEffect.}
proc `/%` *(x, y: int32): int32 {.magic: "DivU", noSideEffect.}
proc `/%` *(x, y: int64): int64 {.magic: "DivU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and divides them. The result is
  ## truncated to fit into the result. This implements modulo arithmetic.
  ## No overflow errors are possible.

proc `%%` *(x, y: int): int {.magic: "ModU", noSideEffect.}
proc `%%` *(x, y: int8): int8 {.magic: "ModU", noSideEffect.}
proc `%%` *(x, y: int16): int16 {.magic: "ModU", noSideEffect.}
proc `%%` *(x, y: int32): int32 {.magic: "ModU", noSideEffect.}
proc `%%` *(x, y: int64): int64 {.magic: "ModU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and compute the modulo of `x` and `y`.
  ## The result is truncated to fit into the result.
  ## This implements modulo arithmetic.
  ## No overflow errors are possible.

proc `<=%` *(x, y: int): bool {.magic: "LeU", noSideEffect.}
proc `<=%` *(x, y: int8): bool {.magic: "LeU", noSideEffect.}
proc `<=%` *(x, y: int16): bool {.magic: "LeU", noSideEffect.}
proc `<=%` *(x, y: int32): bool {.magic: "LeU", noSideEffect.}
proc `<=%` *(x, y: int64): bool {.magic: "LeU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and compares them.
  ## Returns true iff ``unsigned(x) <= unsigned(y)``.

proc `<%` *(x, y: int): bool {.magic: "LtU", noSideEffect.}
proc `<%` *(x, y: int8): bool {.magic: "LtU", noSideEffect.}
proc `<%` *(x, y: int16): bool {.magic: "LtU", noSideEffect.}
proc `<%` *(x, y: int32): bool {.magic: "LtU", noSideEffect.}
proc `<%` *(x, y: int64): bool {.magic: "LtU64", noSideEffect.}
  ## treats `x` and `y` as unsigned and compares them.
  ## Returns true iff ``unsigned(x) < unsigned(y)``.


# floating point operations:
proc `+` *(x: float): float {.magic: "UnaryPlusF64", noSideEffect.}
proc `-` *(x: float): float {.magic: "UnaryMinusF64", noSideEffect.}
proc `+` *(x, y: float): float {.magic: "AddF64", noSideEffect.}
proc `-` *(x, y: float): float {.magic: "SubF64", noSideEffect.}
proc `*` *(x, y: float): float {.magic: "MulF64", noSideEffect.}
proc `/` *(x, y: float): float {.magic: "DivF64", noSideEffect.}
  ## computes the floating point division

proc `==` *(x, y: float): bool {.magic: "EqF64", noSideEffect.}
proc `<=` *(x, y: float): bool {.magic: "LeF64", noSideEffect.}
proc `<`  *(x, y: float): bool {.magic: "LtF64", noSideEffect.}
proc abs*(x: float): float {.magic: "AbsF64", noSideEffect.}
proc min*(x, y: float): float {.magic: "MinF64", noSideEffect.}
proc max*(x, y: float): float {.magic: "MaxF64", noSideEffect.}

# set operators
proc `*` *[T](x, y: set[T]): set[T] {.magic: "MulSet", noSideEffect.}
  ## This operator computes the intersection of two sets.
proc `+` *[T](x, y: set[T]): set[T] {.magic: "PlusSet", noSideEffect.}
  ## This operator computes the union of two sets.
proc `-` *[T](x, y: set[T]): set[T] {.magic: "MinusSet", noSideEffect.}
  ## This operator computes the difference of two sets.
proc `-+-` *[T](x, y: set[T]): set[T] {.magic: "SymDiffSet", noSideEffect.}
  ## computes the symmetric set difference. This is the same as
  ## ``(A - B) + (B - A)``, but more efficient.

# comparison operators:
proc `==` *[T](x, y: ordinal[T]): bool {.magic: "EqEnum", noSideEffect.}
proc `==` *(x, y: pointer): bool {.magic: "EqRef", noSideEffect.}
proc `==` *(x, y: string): bool {.magic: "EqStr", noSideEffect.}
proc `==` *(x, y: cstring): bool {.magic: "EqCString", noSideEffect.}
proc `==` *(x, y: char): bool {.magic: "EqCh", noSideEffect.}
proc `==` *(x, y: bool): bool {.magic: "EqB", noSideEffect.}
proc `==` *[T](x, y: set[T]): bool {.magic: "EqSet", noSideEffect.}
proc `==` *[T](x, y: ref T): bool {.magic: "EqRef", noSideEffect.}
proc `==` *[T](x, y: ptr T): bool {.magic: "EqRef", noSideEffect.}

proc `<=` *[T](x, y: ordinal[T]): bool {.magic: "LeEnum", noSideEffect.}
proc `<=` *(x, y: string): bool {.magic: "LeStr", noSideEffect.}
proc `<=` *(x, y: char): bool {.magic: "LeCh", noSideEffect.}
proc `<=` *[T](x, y: set[T]): bool {.magic: "LeSet", noSideEffect.}
proc `<=` *(x, y: bool): bool {.magic: "LeB", noSideEffect.}
proc `<=` *[T](x, y: ref T): bool {.magic: "LePtr", noSideEffect.}
proc `<=` *(x, y: pointer): bool {.magic: "LePtr", noSideEffect.}

proc `<` *[T](x, y: ordinal[T]): bool {.magic: "LtEnum", noSideEffect.}
proc `<` *(x, y: string): bool {.magic: "LtStr", noSideEffect.}
proc `<` *(x, y: char): bool {.magic: "LtCh", noSideEffect.}
proc `<` *[T](x, y: set[T]): bool {.magic: "LtSet", noSideEffect.}
proc `<` *(x, y: bool): bool {.magic: "LtB", noSideEffect.}
proc `<` *[T](x, y: ref T): bool {.magic: "LtPtr", noSideEffect.}
proc `<` *[T](x, y: ptr T): bool {.magic: "LtPtr", noSideEffect.}
proc `<` *(x, y: pointer): bool {.magic: "LtPtr", noSideEffect.}

template `!=` * (x, y: expr): expr =
  ## unequals operator. This is a shorthand for ``not (x == y)``.
  not (x == y)

template `>=` * (x, y: expr): expr =
  ## "is greater or equals" operator. This is the same as ``y <= x``.
  y <= x

template `>` * (x, y: expr): expr =
  ## "is greater" operator. This is the same as ``y < x``.
  y < x

proc contains*[T](x: set[T], y: T): bool {.magic: "InSet", noSideEffect.}
  ## One should overload this proc if one wants to overload the ``in`` operator.
  ## The parameters are in reverse order! ``a in b`` is a template for
  ## ``contains(b, a)``.
  ## This is because the unification algorithm that Nimrod uses for overload
  ## resolution works from left to right.
  ## But for the ``in`` operator that would be the wrong direction for this
  ## piece of code:
  ##
  ## .. code-block:: Nimrod
  ##   var s: set[range['a'..'z']] = {'a'..'c'}
  ##   writeln(stdout, 'b' in s)
  ##
  ## If ``in`` had been declared as ``[T](elem: T, s: set[T])`` then ``T`` would
  ## have been bound to ``char``. But ``s`` is not compatible to type
  ## ``set[char]``! The solution is to bind ``T`` to ``range['a'..'z']``. This
  ## is achieved by reversing the parameters for ``contains``; ``in`` then
  ## passes its arguments in reverse order.

template `in` * (x, y: expr): expr = contains(y, x)
template `not_in` * (x, y: expr): expr = not contains(y, x)

proc `is` *[T, S](x: T, y: S): bool {.magic: "Is", noSideEffect.}
template `is_not` *(x, y: expr): expr = not (x is y)

proc `of` *[T, S](x: T, y: S): bool {.magic: "Of", noSideEffect.}

proc cmp*[T](x, y: T): int {.procvar.} =
  ## Generic compare proc. Returns a value < 0 iff x < y, a value > 0 iff x > y
  ## and 0 iff x == y. This is useful for writing generic algorithms without
  ## performance loss. This generic implementation uses the `==` and `<`
  ## operators.
  if x == y: return 0
  if x < y: return -1
  return 1

proc cmp*(x, y: string): int {.noSideEffect, procvar.}
  ## Compare proc for strings. More efficient than the generic version.

proc `@` * [IDX, T](a: array[IDX, T]): seq[T] {.
  magic: "ArrToSeq", nosideeffect.}
  ## turns an array into a sequence. This most often useful for constructing
  ## sequences with the array constructor: ``@[1, 2, 3]`` has the type 
  ## ``seq[int]``, while ``[1, 2, 3]`` has the type ``array[0..2, int]``. 

proc setLen*[T](s: var seq[T], newlen: int) {.
  magic: "SetLengthSeq", noSideEffect.}
  ## sets the length of `s` to `newlen`.
  ## ``T`` may be any sequence type.
  ## If the current length is greater than the new length,
  ## ``s`` will be truncated. `s` cannot be nil! To initialize a sequence with
  ## a size, use ``newSeq`` instead. 

proc setLen*(s: var string, newlen: int) {.
  magic: "SetLengthStr", noSideEffect.}
  ## sets the length of `s` to `newlen`.
  ## If the current length is greater than the new length,
  ## ``s`` will be truncated. `s` cannot be nil! To initialize a string with
  ## a size, use ``newString`` instead. 

proc newString*(len: int): string {.
  magic: "NewString", importc: "mnewString", noSideEffect.}
  ## returns a new string of length ``len`` but with uninitialized
  ## content. One needs to fill the string character after character
  ## with the index operator ``s[i]``. This procedure exists only for
  ## optimization purposes; the same effect can be achieved with the
  ## ``&`` operator or with ``add``.

proc newStringOfCap*(cap: int): string {.
  magic: "NewStringOfCap", importc: "rawNewString", noSideEffect.}
  ## returns a new string of length ``0`` but with capacity `cap`.This
  ## procedure exists only for optimization purposes; the same effect can 
  ## be achieved with the ``&`` operator or with ``add``.

proc `&` * (x: string, y: char): string {.
  magic: "ConStrStr", noSideEffect, merge.}
proc `&` * (x: char, y: char): string {.
  magic: "ConStrStr", noSideEffect, merge.}
proc `&` * (x, y: string): string {.
  magic: "ConStrStr", noSideEffect, merge.}
proc `&` * (x: char, y: string): string {.
  magic: "ConStrStr", noSideEffect, merge.}
  ## is the `concatenation operator`. It concatenates `x` and `y`.

# implementation note: These must all have the same magic value "ConStrStr" so
# that the merge optimization works properly. 

proc add*(x: var string, y: char) {.magic: "AppendStrCh", noSideEffect.}
proc add*(x: var string, y: string) {.magic: "AppendStrStr", noSideEffect.}

type
  TEndian* = enum ## is a type describing the endianness of a processor.
    littleEndian, bigEndian

const
  isMainModule* {.magic: "IsMainModule".}: bool = false
    ## is true only when accessed in the main module. This works thanks to
    ## compiler magic. It is useful to embed testing code in a module.

  CompileDate* {.magic: "CompileDate"}: string = "0000-00-00"
    ## is the date of compilation as a string of the form
    ## ``YYYY-MM-DD``. This works thanks to compiler magic.

  CompileTime* {.magic: "CompileTime"}: string = "00:00:00"
    ## is the time of compilation as a string of the form
    ## ``HH:MM:SS``. This works thanks to compiler magic.

  NimrodVersion* {.magic: "NimrodVersion"}: string = "0.0.0"
    ## is the version of Nimrod as a string.
    ## This works thanks to compiler magic.

  NimrodMajor* {.magic: "NimrodMajor"}: int = 0
    ## is the major number of Nimrod's version.
    ## This works thanks to compiler magic.

  NimrodMinor* {.magic: "NimrodMinor"}: int = 0
    ## is the minor number of Nimrod's version.
    ## This works thanks to compiler magic.

  NimrodPatch* {.magic: "NimrodPatch"}: int = 0
    ## is the patch number of Nimrod's version.
    ## This works thanks to compiler magic.

  cpuEndian* {.magic: "CpuEndian"}: TEndian = littleEndian
    ## is the endianness of the target CPU. This is a valuable piece of
    ## information for low-level code only. This works thanks to compiler
    ## magic.
    
  hostOS* {.magic: "HostOS"}: string = ""
    ## a string that describes the host operating system. Possible values:
    ## "windows", "macosx", "linux", "netbsd", "freebsd", "openbsd", "solaris",
    ## "aix".
        
  hostCPU* {.magic: "HostCPU"}: string = ""
    ## a string that describes the host CPU. Possible values:
    ## "i386", "alpha", "powerpc", "sparc", "amd64", "mips", "arm".
  
  appType* {.magic: "AppType"}: string = ""
    ## a string that describes the application type. Possible values:
    ## "console", "gui", "lib".
  
  seqShallowFlag = 1 shl (sizeof(int)*8-1)
  
proc compileOption*(option: string): bool {.
  magic: "CompileOption", noSideEffect.}
  ## can be used to determine an on|off compile-time option. Example:
  ##
  ## .. code-block:: nimrod
  ##   when compileOption("floatchecks"): 
  ##     echo "compiled with floating point NaN and Inf checks"
  
proc compileOption*(option, arg: string): bool {.
  magic: "CompileOptionArg", noSideEffect.}
  ## can be used to determine an enum compile-time option. Example:
  ##
  ## .. code-block:: nimrod
  ##   when compileOption("opt", "size") and compileOption("gc", "boehm"): 
  ##     echo "compiled with optimization for size and uses Boehm's GC"

const
  hasThreadSupport = compileOption("threads")
  hasSharedHeap = defined(boehmgc) # don't share heaps; every thread has its own
  taintMode = compileOption("taintmode")

when taintMode:
  # XXX use a compile time option for it!
  type TaintedString* = distinct string ## a distinct string type that 
                                        ## is `tainted`:idx:. It is an alias for
                                        ## ``string`` if the taint mode is not
                                        ## turned on. Use the ``-d:taintMode``
                                        ## command line switch to turn the taint
                                        ## mode on.
  
  proc len*(s: TaintedString): int {.borrow.}
else:
  type TaintedString* = string


when hasThreadSupport:
  {.pragma: rtlThreadVar, threadvar.}
else:
  {.pragma: rtlThreadVar.}

const
  QuitSuccess* = 0
    ## is the value that should be passed to ``quit`` to indicate
    ## success.

  QuitFailure* = 1
    ## is the value that should be passed to ``quit`` to indicate
    ## failure.

var programResult* {.exportc: "nim_program_result".}: int
  ## modify this varialbe to specify the exit code of the program
  ## under normal circumstances. When the program is terminated
  ## prematurelly using ``quit``, this value is ignored.

proc quit*(errorcode: int = QuitSuccess) {.
  magic: "Exit", importc: "exit", noDecl, noReturn.}
  ## stops the program immediately; before stopping the program the
  ## "quit procedures" are called in the opposite order they were added
  ## with ``addQuitProc``. ``quit`` never returns and ignores any
  ## exception that may have been raised by the quit procedures.
  ## It does *not* call the garbage collector to free all the memory,
  ## unless a quit procedure calls ``GC_collect``.

template sysAssert(cond, msg: expr) =
  when defined(useSysAssert):
    if not cond:
      echo "[SYSASSERT] ", msg
      quit 1
  nil

include "system/inclrtl"

when not defined(ecmascript) and not defined(nimrodVm):
  include "system/cgprocs"

proc add *[T](x: var seq[T], y: T) {.magic: "AppendSeqElem", noSideEffect.}
proc add *[T](x: var seq[T], y: openArray[T]) {.noSideEffect.} =
  ## Generic proc for adding a data item `y` to a container `x`.
  ## For containers that have an order, `add` means *append*. New generic
  ## containers should also call their adding proc `add` for consistency.
  ## Generic code becomes much easier to write if the Nimrod naming scheme is
  ## respected.
  var xl = x.len
  setLen(x, xl + y.len)
  for i in 0..high(y): x[xl+i] = y[i]

proc shallowCopy*[T](x: var T, y: T) {.noSideEffect, magic: "ShallowCopy".}
  ## use this instead of `=` for a `shallow copy`:idx:. The shallow copy
  ## only changes the semantics for sequences and strings (and types which
  ## contain those). Be careful with the changed semantics though! There 
  ## is a reason why the default assignment does a deep copy of sequences
  ## and strings.

proc del*[T](x: var seq[T], i: int) {.noSideEffect.} = 
  ## deletes the item at index `i` by putting ``x[high(x)]`` into position `i`.
  ## This is an O(1) operation.
  var xl = x.len
  shallowCopy(x[i], x[xl-1])
  setLen(x, xl-1)
  
proc delete*[T](x: var seq[T], i: int) {.noSideEffect.} = 
  ## deletes the item at index `i` by moving ``x[i+1..]`` by one position.
  ## This is an O(n) operation.
  var xl = x.len
  for j in i..xl-2: shallowCopy(x[j], x[j+1]) 
  setLen(x, xl-1)
  
proc insert*[T](x: var seq[T], item: T, i = 0) {.noSideEffect.} = 
  ## inserts `item` into `x` at position `i`.
  var xl = x.len
  setLen(x, xl+1)
  var j = xl-1
  while j >= i:
    shallowCopy(x[j+1], x[j])
    dec(j)
  x[i] = item

proc repr*[T](x: T): string {.magic: "Repr", noSideEffect.}
  ## takes any Nimrod variable and returns its string representation. It
  ## works even for complex data graphs with cycles. This is a great
  ## debugging tool.

type
  TAddress* = int
    ## is the signed integer type that should be used for converting
    ## pointers to integer addresses for readability.

  BiggestInt* = int64
    ## is an alias for the biggest signed integer type the Nimrod compiler
    ## supports. Currently this is ``int64``, but it is platform-dependant
    ## in general.

  BiggestFloat* = float64
    ## is an alias for the biggest floating point type the Nimrod
    ## compiler supports. Currently this is ``float64``, but it is
    ## platform-dependant in general.

type # these work for most platforms:
  cchar* {.importc: "char", nodecl.} = char
    ## This is the same as the type ``char`` in *C*.
  cschar* {.importc: "signed char", nodecl.} = byte
    ## This is the same as the type ``signed char`` in *C*.
  cshort* {.importc: "short", nodecl.} = int16
    ## This is the same as the type ``short`` in *C*.
  cint* {.importc: "int", nodecl.} = int32
    ## This is the same as the type ``int`` in *C*.
  clong* {.importc: "long", nodecl.} = int
    ## This is the same as the type ``long`` in *C*.
  clonglong* {.importc: "long long", nodecl.} = int64
    ## This is the same as the type ``long long`` in *C*.
  cfloat* {.importc: "float", nodecl.} = float32
    ## This is the same as the type ``float`` in *C*.
  cdouble* {.importc: "double", nodecl.} = float64
    ## This is the same as the type ``double`` in *C*.
  clongdouble* {.importc: "long double", nodecl.} = BiggestFloat
    ## This is the same as the type ``long double`` in *C*.
    ## This C type is not supported by Nimrod's code generator

  cstringArray* {.importc: "char**", nodecl.} = ptr array [0..50_000, cstring]
    ## This is binary compatible to the type ``char**`` in *C*. The array's
    ## high value is large enough to disable bounds checking in practice.
    ## Use `cstringArrayToSeq` to convert it into a ``seq[string]``.

  PFloat32* = ptr Float32 ## an alias for ``ptr float32``
  PFloat64* = ptr Float64 ## an alias for ``ptr float64``
  PInt64* = ptr Int64 ## an alias for ``ptr int64``
  PInt32* = ptr Int32 ## an alias for ``ptr int32``

proc toFloat*(i: int): float {.
  magic: "ToFloat", noSideEffect, importc: "toFloat".}
  ## converts an integer `i` into a ``float``. If the conversion
  ## fails, `EInvalidValue` is raised. However, on most platforms the
  ## conversion cannot fail.

proc toBiggestFloat*(i: biggestint): biggestfloat {.
  magic: "ToBiggestFloat", noSideEffect, importc: "toBiggestFloat".}
  ## converts an biggestint `i` into a ``biggestfloat``. If the conversion
  ## fails, `EInvalidValue` is raised. However, on most platforms the
  ## conversion cannot fail.

proc toInt*(f: float): int {.
  magic: "ToInt", noSideEffect, importc: "toInt".}
  ## converts a floating point number `f` into an ``int``. Conversion
  ## rounds `f` if it does not contain an integer value. If the conversion
  ## fails (because `f` is infinite for example), `EInvalidValue` is raised.

proc toBiggestInt*(f: biggestfloat): biggestint {.
  magic: "ToBiggestInt", noSideEffect, importc: "toBiggestInt".}
  ## converts a biggestfloat `f` into a ``biggestint``. Conversion
  ## rounds `f` if it does not contain an integer value. If the conversion
  ## fails (because `f` is infinite for example), `EInvalidValue` is raised.

proc addQuitProc*(QuitProc: proc {.noconv.}) {.importc: "atexit", nodecl.}
  ## adds/registers a quit procedure. Each call to ``addQuitProc``
  ## registers another quit procedure. Up to 30 procedures can be
  ## registered. They are executed on a last-in, first-out basis
  ## (that is, the last function registered is the first to be executed).
  ## ``addQuitProc`` raises an EOutOfIndex if ``quitProc`` cannot be
  ## registered.

# Support for addQuitProc() is done by Ansi C's facilities here.
# In case of an unhandled exeption the exit handlers should
# not be called explicitly! The user may decide to do this manually though.

proc copy*(s: string, first = 0): string {.
  magic: "CopyStr", importc: "copyStr", noSideEffect, deprecated.}
proc copy*(s: string, first, last: int): string {.
  magic: "CopyStrLast", importc: "copyStrLast", noSideEffect, 
  deprecated.}
  ## copies a slice of `s` into a new string and returns this new
  ## string. The bounds `first` and `last` denote the indices of
  ## the first and last characters that shall be copied. If ``last``
  ## is omitted, it is treated as ``high(s)``.
  ## **Deprecated since version 0.8.12**: Use ``substr`` instead.

proc substr*(s: string, first = 0): string {.
  magic: "CopyStr", importc: "copyStr", noSideEffect.}
proc substr*(s: string, first, last: int): string {.
  magic: "CopyStrLast", importc: "copyStrLast", noSideEffect.}
  ## copies a slice of `s` into a new string and returns this new
  ## string. The bounds `first` and `last` denote the indices of
  ## the first and last characters that shall be copied. If ``last``
  ## is omitted, it is treated as ``high(s)``. If ``last >= s.len``, ``s.len``
  ## is used instead: This means ``substr`` can also be used to `cut`:idx:
  ## or `limit`:idx: a string's length.

proc zeroMem*(p: Pointer, size: int) {.importc, noDecl.}
  ## overwrites the contents of the memory at ``p`` with the value 0.
  ## Exactly ``size`` bytes will be overwritten. Like any procedure
  ## dealing with raw memory this is *unsafe*.

proc copyMem*(dest, source: Pointer, size: int) {.importc: "memcpy", noDecl.}
  ## copies the contents from the memory at ``source`` to the memory
  ## at ``dest``. Exactly ``size`` bytes will be copied. The memory
  ## regions may not overlap. Like any procedure dealing with raw
  ## memory this is *unsafe*.

proc moveMem*(dest, source: Pointer, size: int) {.importc: "memmove", noDecl.}
  ## copies the contents from the memory at ``source`` to the memory
  ## at ``dest``. Exactly ``size`` bytes will be copied. The memory
  ## regions may overlap, ``moveMem`` handles this case appropriately
  ## and is thus somewhat more safe than ``copyMem``. Like any procedure
  ## dealing with raw memory this is still *unsafe*, though.

proc equalMem*(a, b: Pointer, size: int): bool {.
  importc: "equalMem", noDecl, noSideEffect.}
  ## compares the memory blocks ``a`` and ``b``. ``size`` bytes will
  ## be compared. If the blocks are equal, true is returned, false
  ## otherwise. Like any procedure dealing with raw memory this is
  ## *unsafe*.

proc alloc*(size: int): pointer {.noconv, rtl.}
  ## allocates a new memory block with at least ``size`` bytes. The
  ## block has to be freed with ``realloc(block, 0)`` or
  ## ``dealloc(block)``. The block is not initialized, so reading
  ## from it before writing to it is undefined behaviour!
  ## The allocated memory belongs to its allocating thread!
  ## Use `allocShared` to allocate from a shared heap.
proc alloc0*(size: int): pointer {.noconv, rtl.}
  ## allocates a new memory block with at least ``size`` bytes. The
  ## block has to be freed with ``realloc(block, 0)`` or
  ## ``dealloc(block)``. The block is initialized with all bytes
  ## containing zero, so it is somewhat safer than ``alloc``.
  ## The allocated memory belongs to its allocating thread!
  ## Use `allocShared0` to allocate from a shared heap.
proc realloc*(p: Pointer, newsize: int): pointer {.noconv, rtl.}
  ## grows or shrinks a given memory block. If p is **nil** then a new
  ## memory block is returned. In either way the block has at least
  ## ``newsize`` bytes. If ``newsize == 0`` and p is not **nil**
  ## ``realloc`` calls ``dealloc(p)``. In other cases the block has to
  ## be freed with ``dealloc``.
  ## The allocated memory belongs to its allocating thread!
  ## Use `reallocShared` to reallocate from a shared heap.
proc dealloc*(p: Pointer) {.noconv, rtl.}
  ## frees the memory allocated with ``alloc``, ``alloc0`` or
  ## ``realloc``. This procedure is dangerous! If one forgets to
  ## free the memory a leak occurs; if one tries to access freed
  ## memory (or just freeing it twice!) a core dump may happen
  ## or other memory may be corrupted. 
  ## The freed memory must belong to its allocating thread!
  ## Use `deallocShared` to deallocate from a shared heap.

proc allocShared*(size: int): pointer {.noconv, rtl.}
  ## allocates a new memory block on the shared heap with at
  ## least ``size`` bytes. The block has to be freed with
  ## ``reallocShared(block, 0)`` or ``deallocShared(block)``. The block
  ## is not initialized, so reading from it before writing to it is 
  ## undefined behaviour!
proc allocShared0*(size: int): pointer {.noconv, rtl.}
  ## allocates a new memory block on the shared heap with at 
  ## least ``size`` bytes. The block has to be freed with
  ## ``reallocShared(block, 0)`` or ``deallocShared(block)``.
  ## The block is initialized with all bytes
  ## containing zero, so it is somewhat safer than ``allocShared``.
proc reallocShared*(p: Pointer, newsize: int): pointer {.noconv, rtl.}
  ## grows or shrinks a given memory block on the heap. If p is **nil**
  ## then a new memory block is returned. In either way the block has at least
  ## ``newsize`` bytes. If ``newsize == 0`` and p is not **nil**
  ## ``reallocShared`` calls ``deallocShared(p)``. In other cases the
  ## block has to be freed with ``deallocShared``.
proc deallocShared*(p: Pointer) {.noconv, rtl.}
  ## frees the memory allocated with ``allocShared``, ``allocShared0`` or
  ## ``reallocShared``. This procedure is dangerous! If one forgets to
  ## free the memory a leak occurs; if one tries to access freed
  ## memory (or just freeing it twice!) a core dump may happen
  ## or other memory may be corrupted.

proc swap*[T](a, b: var T) {.magic: "Swap", noSideEffect.}
  ## swaps the values `a` and `b`. This is often more efficient than
  ## ``tmp = a; a = b; b = tmp``. Particularly useful for sorting algorithms.

template `>=%` *(x, y: expr): expr = y <=% x
  ## treats `x` and `y` as unsigned and compares them.
  ## Returns true iff ``unsigned(x) >= unsigned(y)``.

template `>%` *(x, y: expr): expr = y <% x
  ## treats `x` and `y` as unsigned and compares them.
  ## Returns true iff ``unsigned(x) > unsigned(y)``.

proc `$` *(x: int): string {.magic: "IntToStr", noSideEffect.}
  ## The stingify operator for an integer argument. Returns `x`
  ## converted to a decimal string.

proc `$` *(x: int64): string {.magic: "Int64ToStr", noSideEffect.}
  ## The stingify operator for an integer argument. Returns `x`
  ## converted to a decimal string.

proc `$` *(x: float): string {.magic: "FloatToStr", noSideEffect.}
  ## The stingify operator for a float argument. Returns `x`
  ## converted to a decimal string.

proc `$` *(x: bool): string {.magic: "BoolToStr", noSideEffect.}
  ## The stingify operator for a boolean argument. Returns `x`
  ## converted to the string "false" or "true".

proc `$` *(x: char): string {.magic: "CharToStr", noSideEffect.}
  ## The stingify operator for a character argument. Returns `x`
  ## converted to a string.

proc `$` *(x: Cstring): string {.magic: "CStrToStr", noSideEffect.}
  ## The stingify operator for a CString argument. Returns `x`
  ## converted to a string.

proc `$` *(x: string): string {.magic: "StrToStr", noSideEffect.}
  ## The stingify operator for a string argument. Returns `x`
  ## as it is. This operator is useful for generic code, so
  ## that ``$expr`` also works if ``expr`` is already a string.

proc `$` *[T](x: ordinal[T]): string {.magic: "EnumToStr", noSideEffect.}
  ## The stingify operator for an enumeration argument. This works for
  ## any enumeration type thanks to compiler magic. If
  ## a ``$`` operator for a concrete enumeration is provided, this is
  ## used instead. (In other words: *Overwriting* is possible.)

# undocumented:
proc getRefcount*[T](x: ref T): int {.importc: "getRefcount", noSideEffect.}
proc getRefcount*(x: string): int {.importc: "getRefcount", noSideEffect.}
proc getRefcount*[T](x: seq[T]): int {.importc: "getRefcount", noSideEffect.}
  ## retrieves the reference count of an heap-allocated object. The
  ## value is implementation-dependent.

# new constants:
const
  inf* {.magic: "Inf".} = 1.0 / 0.0
    ## contains the IEEE floating point value of positive infinity.
  neginf* {.magic: "NegInf".} = -inf
    ## contains the IEEE floating point value of negative infinity.
  nan* {.magic: "NaN".} = 0.0 / 0.0
    ## contains an IEEE floating point value of *Not A Number*. Note
    ## that you cannot compare a floating point value to this value
    ## and expect a reasonable result - use the `classify` procedure
    ## in the module ``math`` for checking for NaN.

# GC interface:

proc getOccupiedMem*(): int {.rtl.}
  ## returns the number of bytes that are owned by the process and hold data.

proc getFreeMem*(): int {.rtl.}
  ## returns the number of bytes that are owned by the process, but do not
  ## hold any meaningful data.

proc getTotalMem*(): int {.rtl.}
  ## returns the number of bytes that are owned by the process.


iterator countdown*[T](a, b: T, step = 1): T {.inline.} =
  ## Counts from ordinal value `a` down to `b` with the given
  ## step count. `T` may be any ordinal type, `step` may only
  ## be positive.
  var res = a
  while res >= b:
    yield res
    dec(res, step)

iterator countup*[S, T](a: S, b: T, step = 1): T {.inline.} =
  ## Counts from ordinal value `a` up to `b` with the given
  ## step count. `S`, `T` may be any ordinal type, `step` may only
  ## be positive.
  var res: T = a
  while res <= b:
    yield res
    inc(res, step)

iterator `..`*[S, T](a: S, b: T): T {.inline.} =
  ## An alias for `countup`.
  var res: T = a
  while res <= b:
    yield res
    inc res

proc min*(x, y: int): int {.magic: "MinI", noSideEffect.}
proc min*(x, y: int8): int8 {.magic: "MinI", noSideEffect.}
proc min*(x, y: int16): int16 {.magic: "MinI", noSideEffect.}
proc min*(x, y: int32): int32 {.magic: "MinI", noSideEffect.}
proc min*(x, y: int64): int64 {.magic: "MinI64", noSideEffect.}
  ## The minimum value of two integers.

proc min*[T](x: openarray[T]): T = 
  ## The minimum value of an openarray.
  result = x[0]
  for i in 1..high(x): result = min(result, x[i])

proc max*(x, y: int): int {.magic: "MaxI", noSideEffect.}
proc max*(x, y: int8): int8 {.magic: "MaxI", noSideEffect.}
proc max*(x, y: int16): int16 {.magic: "MaxI", noSideEffect.}
proc max*(x, y: int32): int32 {.magic: "MaxI", noSideEffect.}
proc max*(x, y: int64): int64 {.magic: "MaxI64", noSideEffect.}
  ## The maximum value of two integers.

proc max*[T](x: openarray[T]): T = 
  ## The maximum value of an openarray.
  result = x[0]
  for i in 1..high(x): result = max(result, x[i])


iterator items*[T](a: openarray[T]): T {.inline.} =
  ## iterates over each item of `a`.
  var i = 0
  while i < len(a):
    yield a[i]
    inc(i)

iterator items*[IX, T](a: array[IX, T]): T {.inline.} =
  ## iterates over each item of `a`.
  var i = low(IX)
  if i <= high(IX):
    while true:
      yield a[i]
      if i >= high(IX): break
      inc(i)

iterator items*[T](a: seq[T]): T {.inline.} =
  ## iterates over each item of `a`.
  var i = 0
  while i < len(a):
    yield a[i]
    inc(i)

iterator items*(a: string): char {.inline.} =
  ## iterates over each item of `a`.
  var i = 0
  while i < len(a):
    yield a[i]
    inc(i)

iterator items*[T](a: set[T]): T {.inline.} =
  ## iterates over each element of `a`. `items` iterates only over the
  ## elements that are really in the set (and not over the ones the set is
  ## able to hold).
  var i = low(T)
  if i <= high(T):
    while true:
      if i in a: yield i
      if i >= high(T): break
      inc(i)

iterator items*(a: cstring): char {.inline.} =
  ## iterates over each item of `a`.
  var i = 0
  while a[i] != '\0':
    yield a[i]
    inc(i)


iterator pairs*[T](a: openarray[T]): tuple[key: int, val: T] {.inline.} =
  ## iterates over each item of `a`. Yields ``(index, a[index])`` pairs.
  var i = 0
  while i < len(a):
    yield (i, a[i])
    inc(i)

iterator pairs*[IX, T](a: array[IX, T]): tuple[key: IX, val: T] {.inline.} =
  ## iterates over each item of `a`. Yields ``(index, a[index])`` pairs.
  var i = low(IX)
  if i <= high(IX):
    while true:
      yield (i, a[i])
      if i >= high(IX): break
      inc(i)

iterator pairs*[T](a: seq[T]): tuple[key: int, val: T] {.inline.} =
  ## iterates over each item of `a`. Yields ``(index, a[index])`` pairs.
  var i = 0
  while i < len(a):
    yield (i, a[i])
    inc(i)

iterator pairs*(a: string): tuple[key: int, val: char] {.inline.} =
  ## iterates over each item of `a`. Yields ``(index, a[index])`` pairs.
  var i = 0
  while i < len(a):
    yield (i, a[i])
    inc(i)


proc isNil*[T](x: seq[T]): bool {.noSideEffect, magic: "IsNil".}
proc isNil*[T](x: ref T): bool {.noSideEffect, magic: "IsNil".}
proc isNil*(x: string): bool {.noSideEffect, magic: "IsNil".}
proc isNil*[T](x: ptr T): bool {.noSideEffect, magic: "IsNil".}
proc isNil*(x: pointer): bool {.noSideEffect, magic: "IsNil".}
proc isNil*(x: cstring): bool {.noSideEffect, magic: "IsNil".}
  ## Fast check whether `x` is nil. This is sometimes more efficient than
  ## ``== nil``.

proc `&` *[T](x, y: seq[T]): seq[T] {.noSideEffect.} =
  newSeq(result, x.len + y.len)
  for i in 0..x.len-1:
    result[i] = x[i]
  for i in 0..y.len-1:
    result[i+x.len] = y[i]

proc `&` *[T](x: seq[T], y: T): seq[T] {.noSideEffect.} =
  newSeq(result, x.len + 1)
  for i in 0..x.len-1:
    result[i] = x[i]
  result[x.len] = y

proc `&` *[T](x: T, y: seq[T]): seq[T] {.noSideEffect.} =
  newSeq(result, y.len + 1)
  for i in 0..y.len-1:
    result[i] = y[i]
  result[y.len] = x

when not defined(NimrodVM):
  when not defined(ECMAScript):
    proc seqToPtr[T](x: seq[T]): pointer {.inline, nosideeffect.} =
      result = cast[pointer](x)
  else:
    proc seqToPtr[T](x: seq[T]): pointer {.noStackFrame, nosideeffect.} =
      asm """return `x`"""
  
  proc `==` *[T: typeDesc](x, y: seq[T]): bool {.noSideEffect.} =
    ## Generic equals operator for sequences: relies on a equals operator for
    ## the element type `T`.
    if seqToPtr(x) == seqToPtr(y):
      result = true
    elif seqToPtr(x) == nil or seqToPtr(y) == nil:
      result = false
    elif x.len == y.len:
      for i in 0..x.len-1:
        if x[i] != y[i]: return false
      result = true

proc find*[T, S: typeDesc](a: T, item: S): int {.inline.}=
  ## Returns the first index of `item` in `a` or -1 if not found. This requires
  ## appropriate `items` and `==` operations to work.
  for i in items(a):
    if i == item: return
    inc(result)
  result = -1

proc contains*[T](a: openArray[T], item: T): bool {.inline.}=
  ## Returns true if `item` is in `a` or false if not found. This is a shortcut
  ## for ``find(a, item) >= 0``.
  return find(a, item) >= 0

proc pop*[T](s: var seq[T]): T {.inline, noSideEffect.} = 
  ## returns the last item of `s` and decreases ``s.len`` by one. This treats
  ## `s` as a stack and implements the common *pop* operation.
  var L = s.len-1
  result = s[L]
  setLen(s, L)

proc each*[T, S](data: openArray[T], op: proc (x: T): S): seq[S] = 
  ## The well-known ``map`` operation from functional programming. Applies
  ## `op` to every item in `data` and returns the result as a sequence.
  newSeq(result, data.len)
  for i in 0..data.len-1: result[i] = op(data[i])

proc each*[T](data: var openArray[T], op: proc (x: var T)) =
  ## The well-known ``map`` operation from functional programming. Applies
  ## `op` to every item in `data`.
  for i in 0..data.len-1: op(data[i])

iterator fields*[T: tuple](x: T): expr {.magic: "Fields", noSideEffect.}
  ## iterates over every field of `x`. Warning: This really transforms
  ## the 'for' and unrolls the loop. The current implementation also has a bug
  ## that affects symbol binding in the loop body.
iterator fields*[S: tuple, T: tuple](x: S, y: T): tuple[a, b: expr] {.
  magic: "Fields", noSideEffect.}
  ## iterates over every field of `x` and `y`.
  ## Warning: This is really transforms the 'for' and unrolls the loop. 
  ## The current implementation also has a bug that affects symbol binding
  ## in the loop body.
iterator fieldPairs*[T: tuple](x: T): expr {.magic: "FieldPairs", noSideEffect.}
  ## iterates over every field of `x`. Warning: This really transforms
  ## the 'for' and unrolls the loop. The current implementation also has a bug
  ## that affects symbol binding in the loop body.
iterator fieldPairs*[S: tuple, T: tuple](x: S, y: T): tuple[a, b: expr] {.
  magic: "FieldPairs", noSideEffect.}
  ## iterates over every field of `x` and `y`.
  ## Warning: This really transforms the 'for' and unrolls the loop. 
  ## The current implementation also has a bug that affects symbol binding
  ## in the loop body.

proc `==`*[T: tuple](x, y: T): bool = 
  ## generic ``==`` operator for tuples that is lifted from the components
  ## of `x` and `y`.
  for a, b in fields(x, y):
    if a != b: return false
  return true

proc `<=`*[T: tuple](x, y: T): bool = 
  ## generic ``<=`` operator for tuples that is lifted from the components
  ## of `x` and `y`. This implementation uses `cmp`.
  for a, b in fields(x, y):
    var c = cmp(a, b)
    if c < 0: return true
    if c > 0: return false
  return true

proc `<`*[T: tuple](x, y: T): bool = 
  ## generic ``<`` operator for tuples that is lifted from the components
  ## of `x` and `y`. This implementation uses `cmp`.
  for a, b in fields(x, y):
    var c = cmp(a, b)
    if c < 0: return true
    if c > 0: return false
  return false

proc `$`*[T: tuple](x: T): string = 
  ## generic ``$`` operator for tuples that is lifted from the components
  ## of `x`. Example:
  ##
  ## .. code-block:: nimrod
  ##   $(23, 45) == "(23, 45)"
  ##   $() == "()"
  result = "("
  for name, value in fieldPairs(x):
    if result.len > 1: result.add(", ")
    result.add(name)
    result.add(": ")
    result.add($value)
  result.add(")")

when false:
  proc `$`*[T](a: openArray[T]): string = 
    ## generic ``$`` operator for open arrays that is lifted from the elements
    ## of `a`. Example:
    ##
    ## .. code-block:: nimrod
    ##   $[23, 45] == "[23, 45]"
    result = "["
    for x in items(a):
      if result.len > 1: result.add(", ")
      result.add($x)
    result.add("]")

# ----------------- GC interface ---------------------------------------------

proc GC_disable*() {.rtl, inl.}
  ## disables the GC. If called n-times, n calls to `GC_enable` are needed to
  ## reactivate the GC. Note that in most circumstances one should only disable
  ## the mark and sweep phase with `GC_disableMarkAndSweep`.

proc GC_enable*() {.rtl, inl.}
  ## enables the GC again.

proc GC_fullCollect*() {.rtl.}
  ## forces a full garbage collection pass.
  ## Ordinary code does not need to call this (and should not).

type
  TGC_Strategy* = enum ## the strategy the GC should use for the application
    gcThroughput,      ## optimize for throughput
    gcResponsiveness,  ## optimize for responsiveness (default)
    gcOptimizeTime,    ## optimize for speed
    gcOptimizeSpace    ## optimize for memory footprint

proc GC_setStrategy*(strategy: TGC_Strategy) {.rtl.}
  ## tells the GC the desired strategy for the application.

proc GC_enableMarkAndSweep*() {.rtl.}
proc GC_disableMarkAndSweep*() {.rtl.}
  ## the current implementation uses a reference counting garbage collector
  ## with a seldomly run mark and sweep phase to free cycles. The mark and
  ## sweep phase may take a long time and is not needed if the application
  ## does not create cycles. Thus the mark and sweep phase can be deactivated
  ## and activated separately from the rest of the GC.

proc GC_getStatistics*(): string {.rtl.}
  ## returns an informative string about the GC's activity. This may be useful
  ## for tweaking.
  
proc GC_ref*[T](x: ref T) {.magic: "GCref".}
proc GC_ref*[T](x: seq[T]) {.magic: "GCref".}
proc GC_ref*(x: string) {.magic: "GCref".}
  ## marks the object `x` as referenced, so that it will not be freed until
  ## it is unmarked via `GC_unref`. If called n-times for the same object `x`,
  ## n calls to `GC_unref` are needed to unmark `x`. 
  
proc GC_unref*[T](x: ref T) {.magic: "GCunref".}
proc GC_unref*[T](x: seq[T]) {.magic: "GCunref".}
proc GC_unref*(x: string) {.magic: "GCunref".}
  ## see the documentation of `GC_ref`.

template accumulateResult*(iter: expr) =
  ## helps to convert an iterator to a proc.
  result = @[]
  for x in iter: add(result, x)

# we have to compute this here before turning it off in except.nim anyway ...
const nimrodStackTrace = compileOption("stacktrace")

{.push checks: off.}
# obviously we cannot generate checking operations here :-)
# because it would yield into an endless recursion
# however, stack-traces are available for most parts
# of the code

var
  dbgLineHook*: proc
    ## set this variable to provide a procedure that should be called before
    ## each executed instruction. This should only be used by debuggers!
    ## Only code compiled with the ``debugger:on`` switch calls this hook.
  globalRaiseHook*: proc (e: ref E_Base): bool
    ## with this hook you can influence exception handling on a global level.
    ## If not nil, every 'raise' statement ends up calling this hook. Ordinary
    ## application code should never set this hook! You better know what you
    ## do when setting this. If ``globalRaiseHook`` returns false, the
    ## exception is caught and does not propagate further through the call
    ## stack.

  localRaiseHook* {.threadvar.}: proc (e: ref E_Base): bool
    ## with this hook you can influence exception handling on a
    ## thread local level.
    ## If not nil, every 'raise' statement ends up calling this hook. Ordinary
    ## application code should never set this hook! You better know what you
    ## do when setting this. If ``localRaiseHook`` returns false, the exception
    ## is caught and does not propagate further through the call stack.
    
  outOfMemHook*: proc
    ## set this variable to provide a procedure that should be called 
    ## in case of an `out of memory`:idx: event. The standard handler
    ## writes an error message and terminates the program. `outOfMemHook` can
    ## be used to raise an exception in case of OOM like so:
    ## 
    ## .. code-block:: nimrod
    ##
    ##   var gOutOfMem: ref EOutOfMemory
    ##   new(gOutOfMem) # need to be allocated *before* OOM really happened!
    ##   gOutOfMem.msg = "out of memory"
    ## 
    ##   proc handleOOM() =
    ##     raise gOutOfMem
    ##
    ##   system.outOfMemHook = handleOOM
    ##
    ## If the handler does not raise an exception, ordinary control flow
    ## continues and the program is terminated.

type
  PFrame = ptr TFrame
  TFrame {.importc, nodecl, final.} = object
    prev: PFrame
    procname: CString
    line: int # current line number
    filename: CString
    len: int  # length of slots (when not debugging always zero)

when not defined(ECMAScript):
  {.push stack_trace:off.}
  proc add*(x: var string, y: cstring) {.noStackFrame.} =
    var i = 0
    while y[i] != '\0':
      add(x, y[i])
      inc(i)
  {.pop.}
else:
  proc add*(x: var string, y: cstring) {.noStackFrame.} =
    asm """
      var len = `x`[0].length-1;
      for (var i = 0; i < `y`.length; ++i) {
        `x`[0][len] = `y`.charCodeAt(i);
        ++len;
      }
      `x`[0][len] = 0
    """

  proc add*(x: var cstring, y: cstring) {.magic: "AppendStrStr".}

proc echo*[Ty](x: openarray[Ty]) {.magic: "Echo", noSideEffect.}
  ## special built-in that takes a variable number of arguments. Each argument
  ## is converted to a string via ``$``, so it works for user-defined
  ## types that have an overloaded ``$`` operator.
  ## It is roughly equivalent to ``writeln(stdout, x); flush(stdout)``, but
  ## available for the ECMAScript target too.
  ## Unlike other IO operations this is guaranteed to be thread-safe as
  ## ``echo`` is very often used for debugging convenience.

template newException*(exceptn, message: expr): expr = 
  ## creates an exception object of type ``exceptn`` and sets its ``msg`` field
  ## to `message`. Returns the new exception object. 
  block: # open a new scope
    var
      e: ref exceptn
    new(e)
    e.msg = message
    e

when not defined(EcmaScript) and not defined(NimrodVM):
  {.push stack_trace: off.}

  proc initGC()
  when not defined(boehmgc):
    proc initAllocator() {.inline.}

  proc initStackBottom() {.inline.} = 
    # WARNING: This is very fragile! An array size of 8 does not work on my
    # Linux 64bit system. Very strange, but we are at the will of GCC's 
    # optimizer...
    var locals {.volatile.}: pointer
    locals = addr(locals)
    setStackBottom(locals)

  var
    strDesc: TNimType

  strDesc.size = sizeof(string)
  strDesc.kind = tyString
  strDesc.flags = {ntfAcyclic}

  include "system/ansi_c"

  proc cmp(x, y: string): int =
    result = int(c_strcmp(x, y))

  const pccHack = if defined(pcc): "_" else: "" # Hack for PCC
  when defined(windows):
    # work-around C's sucking abstraction:
    # BUGFIX: stdin and stdout should be binary files!
    proc setmode(handle, mode: int) {.importc: pccHack & "setmode",
                                      header: "<io.h>".}
    proc fileno(f: C_TextFileStar): int {.importc: pccHack & "fileno",
                                          header: "<fcntl.h>".}
    var
      O_BINARY {.importc: pccHack & "O_BINARY", nodecl.}: int

    # we use binary mode in Windows:
    setmode(fileno(c_stdin), O_BINARY)
    setmode(fileno(c_stdout), O_BINARY)
  
  when defined(endb):
    proc endbStep()

  # ----------------- IO Part ------------------------------------------------

  type
    CFile {.importc: "FILE", nodecl, final.} = object  # empty record for
                                                       # data hiding
    TFile* = ptr CFile ## The type representing a file handle.

    TFileMode* = enum           ## The file mode when opening a file.
      fmRead,                   ## Open the file for read access only.
      fmWrite,                  ## Open the file for write access only.
      fmReadWrite,              ## Open the file for read and write access.
                                ## If the file does not exist, it will be
                                ## created.
      fmReadWriteExisting,      ## Open the file for read and write access.
                                ## If the file does not exist, it will not be
                                ## created.
      fmAppend                  ## Open the file for writing only; append data
                                ## at the end.

    TFileHandle* = cint ## type that represents an OS file handle; this is
                        ## useful for low-level file access

  # text file handling:
  var
    stdin* {.importc: "stdin", noDecl.}: TFile   ## The standard input stream.
    stdout* {.importc: "stdout", noDecl.}: TFile ## The standard output stream.
    stderr* {.importc: "stderr", noDecl.}: TFile
      ## The standard error stream.
      ##
      ## Note: In my opinion, this should not be used -- the concept of a
      ## separate error stream is a design flaw of UNIX. A seperate *message
      ## stream* is a good idea, but since it is named ``stderr`` there are few
      ## programs out there that distinguish properly between ``stdout`` and
      ## ``stderr``. So, that's what you get if you don't name your variables
      ## appropriately. It also annoys people if redirection
      ## via ``>output.txt`` does not work because the program writes
      ## to ``stderr``.

  proc Open*(f: var TFile, filename: string,
             mode: TFileMode = fmRead, bufSize: int = -1): Bool
    ## Opens a file named `filename` with given `mode`.
    ##
    ## Default mode is readonly. Returns true iff the file could be opened.
    ## This throws no exception if the file could not be opened.

  proc Open*(f: var TFile, filehandle: TFileHandle,
             mode: TFileMode = fmRead): Bool
    ## Creates a ``TFile`` from a `filehandle` with given `mode`.
    ##
    ## Default mode is readonly. Returns true iff the file could be opened.
    
  proc Open*(filename: string,
             mode: TFileMode = fmRead, bufSize: int = -1): TFile = 
    ## Opens a file named `filename` with given `mode`.
    ##
    ## Default mode is readonly. Raises an ``IO`` exception if the file
    ## could not be opened.
    if not open(result, filename, mode, bufSize):
      raise newException(EIO, "cannot open: " & filename)

  proc reopen*(f: TFile, filename: string, mode: TFileMode = fmRead): bool
    ## reopens the file `f` with given `filename` and `mode`. This 
    ## is often used to redirect the `stdin`, `stdout` or `stderr`
    ## file variables.
    ##
    ## Default mode is readonly. Returns true iff the file could be reopened.

  proc Close*(f: TFile) {.importc: "fclose", nodecl.}
    ## Closes the file.

  proc EndOfFile*(f: TFile): Bool
    ## Returns true iff `f` is at the end.
    
  proc readChar*(f: TFile): char {.importc: "fgetc", nodecl.}
    ## Reads a single character from the stream `f`. If the stream
    ## has no more characters, `EEndOfFile` is raised.
  proc FlushFile*(f: TFile) {.importc: "fflush", noDecl.}
    ## Flushes `f`'s buffer.

  proc readAll*(file: TFile): TaintedString
    ## Reads all data from the stream `file`. Raises an IO exception
    ## in case of an error
  
  proc readFile*(filename: string): TaintedString
    ## Opens a file named `filename` for reading. Then calls `readAll`
    ## and closes the file afterwards. Returns the string. 
    ## Raises an IO exception in case of an error.

  proc writeFile*(filename, content: string)
    ## Opens a file named `filename` for writing. Then writes the
    ## `content` completely to the file and closes the file afterwards.
    ## Raises an IO exception in case of an error.

  proc write*(f: TFile, r: float)
  proc write*(f: TFile, i: int)
  proc write*(f: TFile, i: biggestInt)
  proc write*(f: TFile, r: biggestFloat)
  proc write*(f: TFile, s: string)
  proc write*(f: TFile, b: Bool)
  proc write*(f: TFile, c: char)
  proc write*(f: TFile, c: cstring)
  proc write*(f: TFile, a: openArray[string])
    ## Writes a value to the file `f`. May throw an IO exception.

  proc readLine*(f: TFile): TaintedString
    ## reads a line of text from the file `f`. May throw an IO exception.
    ## A line of text may be delimited by ``CR``, ``LF`` or
    ## ``CRLF``. The newline character(s) are not part of the returned string.
  
  proc readLine*(f: TFile, line: var TaintedString): bool
    ## reads a line of text from the file `f` into `line`. `line` must not be
    ## ``nil``! May throw an IO exception.
    ## A line of text may be delimited by ``CR``, ``LF`` or
    ## ``CRLF``. The newline character(s) are not part of the returned string.
    ## Returns ``false`` if the end of the file has been reached, ``true``
    ## otherwise. If ``false`` is returned `line` contains no new data.
  proc writeln*[Ty](f: TFile, x: Ty) {.inline.}
    ## writes a value `x` to `f` and then writes "\n".
    ## May throw an IO exception.

  proc writeln*[Ty](f: TFile, x: openArray[Ty]) {.inline.}
    ## writes a value `x` to `f` and then writes "\n".
    ## May throw an IO exception.

  proc getFileSize*(f: TFile): int64
    ## retrieves the file size (in bytes) of `f`.

  proc ReadBytes*(f: TFile, a: var openarray[byte], start, len: int): int
    ## reads `len` bytes into the buffer `a` starting at ``a[start]``. Returns
    ## the actual number of bytes that have been read which may be less than
    ## `len` (if not as many bytes are remaining), but not greater.

  proc ReadChars*(f: TFile, a: var openarray[char], start, len: int): int
    ## reads `len` bytes into the buffer `a` starting at ``a[start]``. Returns
    ## the actual number of bytes that have been read which may be less than
    ## `len` (if not as many bytes are remaining), but not greater.

  proc readBuffer*(f: TFile, buffer: pointer, len: int): int
    ## reads `len` bytes into the buffer pointed to by `buffer`. Returns
    ## the actual number of bytes that have been read which may be less than
    ## `len` (if not as many bytes are remaining), but not greater.

  proc writeBytes*(f: TFile, a: openarray[byte], start, len: int): int
    ## writes the bytes of ``a[start..start+len-1]`` to the file `f`. Returns
    ## the number of actual written bytes, which may be less than `len` in case
    ## of an error.

  proc writeChars*(f: tFile, a: openarray[char], start, len: int): int
    ## writes the bytes of ``a[start..start+len-1]`` to the file `f`. Returns
    ## the number of actual written bytes, which may be less than `len` in case
    ## of an error.

  proc writeBuffer*(f: TFile, buffer: pointer, len: int): int
    ## writes the bytes of buffer pointed to by the parameter `buffer` to the
    ## file `f`. Returns the number of actual written bytes, which may be less
    ## than `len` in case of an error.

  proc setFilePos*(f: TFile, pos: int64)
    ## sets the position of the file pointer that is used for read/write
    ## operations. The file's first byte has the index zero.

  proc getFilePos*(f: TFile): int64
    ## retrieves the current position of the file pointer that is used to
    ## read from the file `f`. The file's first byte has the index zero.

  proc fileHandle*(f: TFile): TFileHandle {.importc: "fileno",
                                            header: "<stdio.h>"}
    ## returns the OS file handle of the file ``f``. This is only useful for
    ## platform specific programming.

  proc cstringArrayToSeq*(a: cstringArray, len: int): seq[string] =
    ## converts a ``cstringArray`` to a ``seq[string]``. `a` is supposed to be
    ## of length ``len``.
    newSeq(result, len)
    for i in 0..len-1: result[i] = $a[i]

  proc cstringArrayToSeq*(a: cstringArray): seq[string] =
    ## converts a ``cstringArray`` to a ``seq[string]``. `a` is supposed to be
    ## terminated by ``nil``.
    var L = 0
    while a[L] != nil: inc(L)
    result = cstringArrayToSeq(a, L)

  # -------------------------------------------------------------------------

  proc allocCStringArray*(a: openArray[string]): cstringArray =
    ## creates a NULL terminated cstringArray from `a`. The result has to
    ## be freed with `deallocCStringArray` after it's not needed anymore.
    result = cast[cstringArray](alloc0((a.len+1) * sizeof(cstring)))
    for i in 0 .. a.high:
      # XXX get rid of this string copy here:
      var x = a[i]
      result[i] = cast[cstring](alloc0(x.len+1))
      copyMem(result[i], addr(x[0]), x.len)

  proc deallocCStringArray*(a: cstringArray) =
    ## frees a NULL terminated cstringArray.
    var i = 0
    while a[i] != nil:
      dealloc(a[i])
      inc(i)
    dealloc(a)

  proc atomicInc*(memLoc: var int, x: int = 1): int {.inline, discardable.}
    ## atomic increment of `memLoc`. Returns the value after the operation.
  
  proc atomicDec*(memLoc: var int, x: int = 1): int {.inline, discardable.}
    ## atomic decrement of `memLoc`. Returns the value after the operation.

  include "system/atomics"

  type
    PSafePoint = ptr TSafePoint
    TSafePoint {.compilerproc, final.} = object
      prev: PSafePoint # points to next safe point ON THE STACK
      status: int
      context: C_JmpBuf
  
  when defined(initAllocator):
    initAllocator()
  when hasThreadSupport:
    include "system/syslocks"
    include "system/threads"
  else:
    initStackBottom()
    initGC()
    
  {.push stack_trace: off.}
  include "system/excpt"
  # we cannot compile this with stack tracing on
  # as it would recurse endlessly!
  include "system/arithm"
  {.pop.} # stack trace
  {.pop.} # stack trace
      
  include "system/dyncalls"
  include "system/sets"

  const
    GenericSeqSize = (2 * sizeof(int))
    
  proc reprAny(p: pointer, typ: PNimType): string {.compilerRtl.}

  proc getDiscriminant(aa: Pointer, n: ptr TNimNode): int =
    sysAssert(n.kind == nkCase, "getDiscriminant: node != nkCase")
    var d: int
    var a = cast[TAddress](aa)
    case n.typ.size
    of 1: d = ze(cast[ptr int8](a +% n.offset)[])
    of 2: d = ze(cast[ptr int16](a +% n.offset)[])
    of 4: d = int(cast[ptr int32](a +% n.offset)[])
    else: sysAssert(false, "getDiscriminant: invalid n.typ.size")
    return d

  proc selectBranch(aa: Pointer, n: ptr TNimNode): ptr TNimNode =
    var discr = getDiscriminant(aa, n)
    if discr <% n.len:
      result = n.sons[discr]
      if result == nil: result = n.sons[n.len]
      # n.sons[n.len] contains the ``else`` part (but may be nil)
    else:
      result = n.sons[n.len]

  include "system/mmdisp"
  {.push stack_trace: off.}
  include "system/sysstr"
  {.pop.}

  include "system/sysio"
  when hasThreadSupport:
    include "system/channels"

  iterator lines*(filename: string): TaintedString =
    ## Iterate over any line in the file named `filename`.
    ## If the file does not exist `EIO` is raised.
    var f = open(filename)
    var res = TaintedString(newStringOfCap(80))
    while f.readLine(res): yield res
    close(f)

  iterator lines*(f: TFile): TaintedString =
    ## Iterate over any line in the file `f`.
    var res = TaintedString(newStringOfCap(80))
    while f.readLine(res): yield TaintedString(res)

  include "system/assign"
  include "system/repr"

  proc getCurrentException*(): ref E_Base {.compilerRtl, inl.} =
    ## retrieves the current exception; if there is none, nil is returned.
    result = currException

  proc getCurrentExceptionMsg*(): string {.inline.} =
    ## retrieves the error message that was attached to the current
    ## exception; if there is none, "" is returned.
    var e = getCurrentException()
    return if e == nil: "" else: e.msg

  {.push stack_trace: off.}
  when defined(endb):
    include "system/debugger"

  when defined(profiler):
    include "system/profiler"
  {.pop.} # stacktrace

  proc likely*(val: bool): bool {.importc: "likely", nodecl, nosideeffect.}
    ## can be used to mark a condition to be likely. This is a hint for the 
    ## optimizer.
  
  proc unlikely*(val: bool): bool {.importc: "unlikely", nodecl, nosideeffect.}
    ## can be used to mark a condition to be unlikely. This is a hint for the 
    ## optimizer.
    
  proc rawProc*[T: proc](x: T): pointer {.noSideEffect, inline.} =
    ## retrieves the raw proc pointer of the closure `x`. This is
    ## useful for interfacing closures with C.
    {.emit: """
    `result` = `x`.ClPrc;
    """.}

  proc rawEnv*[T: proc](x: T): pointer {.noSideEffect, inline.} =
    ## retrieves the raw environment pointer of the closure `x`. This is
    ## useful for interfacing closures with C.
    {.emit: """
    `result` = `x`.ClEnv;
    """.}

elif defined(ecmaScript) or defined(NimrodVM):
  # Stubs:
  proc GC_disable() = nil
  proc GC_enable() = nil
  proc GC_fullCollect() = nil
  proc GC_setStrategy(strategy: TGC_Strategy) = nil
  proc GC_enableMarkAndSweep() = nil
  proc GC_disableMarkAndSweep() = nil
  proc GC_getStatistics(): string = return ""
  
  proc getOccupiedMem(): int = return -1
  proc getFreeMem(): int = return -1
  proc getTotalMem(): int = return -1

  proc dealloc(p: pointer) = nil
  proc alloc(size: int): pointer = nil
  proc alloc0(size: int): pointer = nil
  proc realloc(p: Pointer, newsize: int): pointer = nil

  proc allocShared(size: int): pointer = nil
  proc allocShared0(size: int): pointer = nil
  proc deallocShared(p: pointer) = nil
  proc reallocShared(p: pointer, newsize: int): pointer = nil

  when defined(ecmaScript):
    include "system/ecmasys"
    include "system/reprjs"
  elif defined(NimrodVM):
    proc cmp(x, y: string): int =
      if x == y: return 0
      if x < y: return -1
      return 1

proc quit*(errormsg: string, errorcode = QuitFailure) {.noReturn.} =
  ## a shorthand for ``echo(errormsg); quit(errorcode)``.
  echo(errormsg)
  quit(errorcode)

{.pop.} # checks
{.pop.} # hints

proc `/`*(x, y: int): float {.inline, noSideEffect.} =
  ## integer division that results in a float.
  result = toFloat(x) / toFloat(y)

template `-|`(b, s: expr): expr =
  (if b >= 0: b else: s.len + b)

proc `[]`*(s: string, x: TSlice[int]): string {.inline.} =
  ## slice operation for strings. Negative indexes are supported.
  result = s.substr(x.a-|s, x.b-|s)

template spliceImpl(s, a, L, b: expr): stmt =
  # make room for additional elements or cut:
  var slen = s.len
  var shift = b.len - L
  var newLen = slen + shift
  if shift > 0:
    # enlarge:
    setLen(s, newLen)
    for i in countdown(newLen-1, a+shift+1): shallowCopy(s[i], s[i-shift])
  else:
    for i in countup(a+b.len, s.len-1+shift): shallowCopy(s[i], s[i-shift])
    # cut down:
    setLen(s, newLen)
  # fill the hole:
  for i in 0 .. <b.len: s[i+a] = b[i]  

proc `[]=`*(s: var string, x: TSlice[int], b: string) = 
  ## slice assignment for strings. Negative indexes are supported. If
  ## ``b.len`` is not exactly the number of elements that are referred to
  ## by `x`, a `splice`:idx: is performed:
  ##
  ## .. code-block:: nimrod
  ##   var s = "abcdef"
  ##   s[1 .. -2] = "xyz"
  ##   assert s == "axyzf"
  var a = x.a-|s
  var L = x.b-|s - a + 1
  if L == b.len:
    for i in 0 .. <L: s[i+a] = b[i]
  else:
    spliceImpl(s, a, L, b)

proc `[]`*[Idx, T](a: array[Idx, T], x: TSlice[int]): seq[T] =
  ## slice operation for arrays. Negative indexes are **not** supported
  ## because the array might have negative bounds.
  var L = x.b - x.a + 1
  newSeq(result, L)
  for i in 0.. <L: result[i] = a[i + x.a]

proc `[]=`*[Idx, T](a: var array[Idx, T], x: TSlice[int], b: openArray[T]) =
  ## slice assignment for arrays. Negative indexes are **not** supported
  ## because the array might have negative bounds.
  var L = x.b - x.a + 1
  if L == b.len:
    for i in 0 .. <L: a[i+x.a] = b[i]
  else:
    raise newException(EOutOfRange, "differing lengths for slice assignment")

proc `[]`*[Idx, T](a: array[Idx, T], x: TSlice[Idx]): seq[T] =
  ## slice operation for arrays. Negative indexes are **not** supported
  ## because the array might have negative bounds.
  var L = ord(x.b) - ord(x.a) + 1
  newSeq(result, L)
  var j = x.a
  for i in 0.. <L: 
    result[i] = a[j]
    inc(j)

proc `[]=`*[Idx, T](a: var array[Idx, T], x: TSlice[Idx], b: openArray[T]) =
  ## slice assignment for arrays. Negative indexes are **not** supported
  ## because the array might have negative bounds.
  var L = ord(x.b) - ord(x.a) + 1
  if L == b.len:
    var j = x.a
    for i in 0 .. <L: 
      a[j] = b[i]
      inc(j)
  else:
    raise newException(EOutOfRange, "differing lengths for slice assignment")

proc `[]`*[T](s: seq[T], x: TSlice[int]): seq[T] = 
  ## slice operation for sequences. Negative indexes are supported.
  var a = x.a-|s
  var L = x.b-|s - a + 1
  newSeq(result, L)
  for i in 0.. <L: result[i] = s[i + a]

proc `[]=`*[T](s: var seq[T], x: TSlice[int], b: openArray[T]) = 
  ## slice assignment for sequences. Negative indexes are supported. If
  ## ``b.len`` is not exactly the number of elements that are referred to
  ## by `x`, a `splice`:idx: is performed. 
  var a = x.a-|s
  var L = x.b-|s - a + 1
  if L == b.len:
    for i in 0 .. <L: s[i+a] = b[i]
  else:
    spliceImpl(s, a, L, b)

proc getTypeInfo*[T](x: T): pointer {.magic: "GetTypeInfo".}
  ## get type information for `x`. Ordinary code should not use this, but
  ## the `typeinfo` module instead.
  
proc slurp*(filename: string): string {.magic: "Slurp".}
  ## compiletime ``readFile`` proc for easy `resource`:idx: embedding:
  ## .. code-block:: nimrod
  ##
  ##   const myResource = slurp"mydatafile.bin"
  ##

proc `+=`*[T](x, y: ordinal[T]) {.magic: "Inc", noSideEffect.}
  ## Increments an ordinal

proc `-=`*[T](x, y: ordinal[T]) {.magic: "Dec", noSideEffect.}
  ## Decrements an ordinal

proc `*=`*[T](x: var ordinal[T], y: ordinal[T]) {.inline, noSideEffect.} =
  ## Binary `*=` operator for ordinals
  x = x * y

proc `+=` *(x: var float, y:float) {.inline, noSideEffect.} =
  ## Increments in placee a floating point number
  x = x + y

proc `-=` *(x: var float, y:float) {.inline, noSideEffect.} =
  ## Decrements in place a floating point number
  x = x - y

proc `*=` *(x: var float, y:float) {.inline, noSideEffect.} =
  ## Multiplies in place a floating point number
  x = x * y

proc `/=` *(x: var float, y:float) {.inline, noSideEffect.} =
  ## Divides in place a floating point number
  x = x / y

proc `&=`* (x: var string, y: string) {.magic: "AppendStrStr", noSideEffect.}

proc rand*(max: int): int {.magic: "Rand", sideEffect.}
  ## compile-time `random` function. Useful for debugging.

proc astToStr*[T](x: T): string {.magic: "AstToStr", noSideEffect.}
  ## converts the AST of `x` into a string representation. This is very useful
  ## for debugging.
  
proc InstantiationInfo*(index = -1): tuple[filename: string, line: int] {.
  magic: "InstantiationInfo", noSideEffect.}
  ## provides access to the compiler's instantiation stack line information.
  ## This is only useful for advanced meta programming. See the implementation
  ## of `assert` for an example.
  
proc raiseAssert(msg: string) {.noinline.} =
  raise newException(EAssertionFailed, msg)
  
template assert*(cond: expr, msg = "") =
  ## provides a means to implement `programming by contracts`:idx: in Nimrod.
  ## ``assert`` evaluates expression ``cond`` and if ``cond`` is false, it
  ## raises an ``EAssertionFailure`` exception. However, the compiler may
  ## not generate any code at all for ``assert`` if it is advised to do so.
  ## Use ``assert`` for debugging purposes only.
  bind raiseAssert, InstantiationInfo
  when compileOption("assertions"):
    {.line.}:
      if not cond:
        raiseAssert(astToStr(cond) & ' ' & msg)

template doAssert*(cond: expr, msg = "") =
  ## same as `assert` but is always turned on and not affected by the
  ## ``--assertions`` command line switch.
  bind raiseAssert, InstantiationInfo
  {.line: InstantiationInfo().}:
    if not cond:
      raiseAssert(astToStr(cond) & ' ' & msg)


proc shallow*[T](s: seq[T]) {.noSideEffect, inline.} =
  ## marks a sequence `s` as `shallow`:idx:. Subsequent assignments will not
  ## perform deep copies of `s`. This is only useful for optimization 
  ## purposes.
  when not defined(EcmaScript) and not defined(NimrodVM):
    var s = cast[PGenericSeq](s)
    s.reserved = s.reserved or seqShallowFlag

proc shallow*(s: string) {.noSideEffect, inline.} =
  ## marks a string `s` as `shallow`:idx:. Subsequent assignments will not
  ## perform deep copies of `s`. This is only useful for optimization 
  ## purposes.
  when not defined(EcmaScript) and not defined(NimrodVM):
    var s = cast[PGenericSeq](s)
    s.reserved = s.reserved or seqShallowFlag


when defined(initDebugger):
  initDebugger()

