module DY.HandsOnSessionLogin.Extraction

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.HandsOnSessionLogin.Protocol

let run () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Programm Output *************\n" in
  // 1. Initialize principals and domains
  let client:principal = "emilys" in
  let domain:domain_t = ["dummyjson"; "com"] in
  let server = http_config_login.domain_to_principal domain in

  // 2. Initialize initial state
  let real_password = serialize usage_rand_string {rand = "emilyspass"} in
  let* password = mk_rand (AeadKey "" real_password) (comm_label client server) 32 in

  let* sid_client = new_session_id client in
  set_state client sid_client (InitialStateClient domain password);*

  // 3. Initialize communication layer
  let*? comm_keys_ids_client, comm_keys_ids_server = initialize_communication_reqres (http_t web_types kv_types) client server in
  
  // 4. Call client protocol functions
  let*? sid, msg_id = api_request comm_keys_ids_client client sid_client in
  let*? () = api_response client sid msg_id in

  return (Some ())

// Execute ``run ()`` when the program runs
#push-options "--warn_error -272"
let _ = run () empty_trace
#pop-options
