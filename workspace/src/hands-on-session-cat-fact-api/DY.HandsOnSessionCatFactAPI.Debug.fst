module DY.HandsOnSessionCatFactAPI.Debug

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSessionCatFactAPI.Protocol

let debug () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Trace *************\n" in
  // 1. Initialize principals
  let client:principal = "Alice" in
  let server:principal = "Bob" in

  // 2. Initialize communication layer
  let*? comm_keys_ids_client, comm_keys_ids_server = initialize_communication_reqres (http_t web_types kv_types) client server in
  
  // 3. Call protocol functions
  let*? sid, msg_id = api_request comm_keys_ids_client client in
  let*? msg_id = api_server comm_keys_ids_server server msg_id in
  let*? () = api_response client sid msg_id in

  let* tr = get_trace in
  let _ = IO.debug_print_string (
      trace_to_string default_http_trace_printers tr
    ) in
  
  return (Some ())

// Execute ``debug ()`` when the program runs
#push-options "--warn_error -272"
let _ = debug () empty_trace
#pop-options