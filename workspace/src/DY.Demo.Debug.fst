module DY.Demo.Debug

open DY.Core
open DY.Lib

let debug () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Trace *************\n" in
  let alice:principal = "Alice" in
  let bob:principal = "Bob" in
  let* nonce = mk_rand NoUsage (join (principal_label alice) (principal_label bob)) 32 in
  let* msg_id = send_msg nonce in

  let* tr = get_trace in
  let _ = IO.debug_print_string (
      trace_to_string default_trace_to_string_printers tr
    ) in
  
  return (Some ())

// Execute ``debug ()`` when the program runs
#push-options "--warn_error -272"
let _ = debug () empty_trace
#pop-options