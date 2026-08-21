module DY.HandsOnSessionCatFactAPI.Extraction

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSessionCatFactAPI.Protocol

let run () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Programm Output *************\n" in
  // 1. Initialize principals
  let client:principal = "Alice" in
  let server:principal = "Bob" in

  // 2. Initialize communication layer
  let*? comm_keys_ids_client, comm_keys_ids_server = initialize_communication_reqres (http_t web_types kv_types) client server in
  
  // 3. Call client functions
  let*? sid, msg_id = api_request comm_keys_ids_client client in
  let*? () = api_response client sid msg_id in

  return (Some ())

// Execute ``run ()`` when the program runs
#push-options "--warn_error -272"
let _ = run () empty_trace
#pop-options