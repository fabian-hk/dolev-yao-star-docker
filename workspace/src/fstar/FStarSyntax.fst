module FStarSyntax

val fibonacci: nat -> int
let rec fibonacci n =
  if n <= 1 then n 
  else (
    let res:int = fibonacci (n-1) + fibonacci (n-2) in
    res  
  )

let test_fibonacci () =
  assert(fibonacci 0 = 0);
  assert(fibonacci 1 = 1);
  assert(fibonacci 2 = 1);
  assert(fibonacci 3 = 2);
  assert(fibonacci 4 = 3);
  assert(fibonacci 5 = 5);
  assert(fibonacci 6 = 8);
  assert(fibonacci 7 = 13);
  assert(fibonacci 8 = 21);
  ()

val fibonacci_greater_than_arg:
  n:nat ->
  Lemma
  (requires
    n >= 5
  )
  (ensures
    fibonacci n >= n
  )
let rec fibonacci_greater_than_arg n =
  if n <= 7 then () else (
    fibonacci_greater_than_arg (n-1);
    fibonacci_greater_than_arg (n-2);
    ()
  )

type shape =
  | Square: w:nat -> shape
  | Rectangle: w:nat -> h:nat -> shape
  | Triangle: a:nat -> b:nat -> c:nat -> shape

val perimeter: shape -> nat
let perimeter s =
  match s with
  | Square w -> op_Multiply 4 w
  | Rectangle w h -> op_Multiply 2 w + op_Multiply 2 h
  | Triangle a b c -> a + b + c


(*** More examples ***)

val square: int -> int
let square n = op_Multiply n n

let test_square () =
  assert(square 2 = 4);
  assert(square (-2) = 4);
  assert(square 4 = 16);
  ()

val square_greater_zero:
  n:int ->
  Lemma
  (ensures
    square n >= 0
  )
let square_greater_zero n = ()

val square_rising_steadily:
  n0:int -> n1:int ->
  Lemma
  (requires
    abs n0 < abs n1
  )
  (ensures
    square n0 < square n1
  )
let square_rising_steadily n0 n1 = ()

  
val faculty: nat -> nat
let rec faculty n =
  if n <= 1 then 1 else op_Multiply n (faculty (n-1))

let test_faculty () =
  assert(faculty 0 = 1);
  assert(faculty 1 = 1);
  assert(faculty 4 = 24);
  assert(faculty 10 = 3628800);
  ()

val faculity_rising_steadily:
  n:nat ->
  Lemma
  (requires
    n >= 1
  )
  (ensures
    faculty n < faculty (n+1)
  )
let rec faculity_rising_steadily n =
  if n < 2 then () else faculity_rising_steadily (n-1)

