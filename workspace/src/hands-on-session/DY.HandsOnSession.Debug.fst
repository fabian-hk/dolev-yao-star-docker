module DY.HandsOnSession.Debug

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSession.Protocol

let debug () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Trace *************\n" in

  // 1. Initialize principals

  // 2. Initialize communication layer

  // 3. Call protocol functions

  let* tr = get_trace in
  let _ = IO.debug_print_string (
      trace_to_string default_http_trace_printers tr
    ) in
  
  return (Some ())

// Execute ``debug ()`` when the program runs
#push-options "--warn_error -272"
let _ = debug () empty_trace
#pop-options