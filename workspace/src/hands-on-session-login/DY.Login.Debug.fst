module DY.Login.Debug

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

open DY.Login.Protocol

let debug () : traceful (option unit)  =
  let _ = IO.debug_print_string "************* Trace *************\n" in
  let client:principal = "emilys" in
  let domain:domain_t = ["dummyjson"; "com"] in
  let server = http_config_login.domain_to_principal domain in

  let real_password = serialize usage_rand_string {rand = "emilyspass"} in
  let* password = mk_rand (AeadKey "" real_password) (comm_label client server) 32 in

  let* sid_client = new_session_id client in
  set_state client sid_client (InitialStateClient domain password);*

  let* sid_server = new_session_id server in
  set_state server sid_server (InitialStateServer client password);*

  let*? comm_keys_ids_client, comm_keys_ids_server = initialize_communication_reqres (http_t web_types kv_types) client server in
  let*? sid, msg_id = api_request comm_keys_ids_client client sid_client in

  let*? msg_id = api_server comm_keys_ids_server server sid_server msg_id in

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
