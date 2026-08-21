module DY.HandsOnSessionLogin.Extraction

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSessionLogin.Protocol

let run () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Programm Output *************\n" in
  // 1. Initialize principals and domains

  // 2. Initialize initial state

  // 3. Initialize communication layer
  
  // 4. Call client protocol functions

  return (Some ())

// Execute ``run ()`` when the program runs
#push-options "--warn_error -272"
let _ = run () empty_trace
#pop-options
