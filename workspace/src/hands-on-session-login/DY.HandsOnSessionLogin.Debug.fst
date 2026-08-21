module DY.HandsOnSessionLogin.Debug

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSessionLogin.Protocol

let debug () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Trace *************\n" in
  // 1. Initialize principals and domains

  // 2. Initialize initial states

  // 3. Initialize communication layer
  
  // 4. Call protocol functions

  let* tr = get_trace in
  let _ = IO.debug_print_string (
      trace_to_string default_http_trace_printers tr
    ) in
  
  return (Some ())

// Execute ``debug ()`` when the program runs
#push-options "--warn_error -272"
let _ = debug () empty_trace
#pop-options
