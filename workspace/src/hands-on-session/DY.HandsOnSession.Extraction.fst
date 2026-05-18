module DY.HandsOnSession.Extraction

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSession.Protocol

let run () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Programm Output *************\n" in
  
  // 1. Initialize principals

  // 2. Initialize communication layer

  // 3. Call client functions

  return (Some ())

// Execute ``run ()`` when the program runs
#push-options "--warn_error -272"
let _ = run () empty_trace
#pop-options