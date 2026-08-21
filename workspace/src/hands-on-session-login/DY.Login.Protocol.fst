module DY.Login.Protocol

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

(*
  DY* model describing a client login at:
  https://dummyjson.com/auth/login
*)

(*** Protocol State Definition ***)

[@@with_bytes bytes]
type state_t =
  | InitialStateClient: domain:domain_t -> password:bytes -> state_t
  | InitialStateServer: client:principal -> password:bytes -> state_t
  | SendRequest: http_meta_data web_types kv_types -> state_t

%splice [ps_state_t] (gen_parser (`state_t))
%splice [ps_state_t_is_well_formed] (gen_is_well_formed_lemma (`state_t))

instance parseable_serializeable_bytes_state_t: parseable_serializeable bytes state_t
  = mk_parseable_serializeable ps_state_t

instance local_state_state_t: local_state state_t = {
  tag = "LoginAPI.State";
  format = parseable_serializeable_bytes_state_t;
}


(*** Event Definition ***)

[@@with_bytes bytes]
type event_t =
  | ClientAuthenticatesToServer: client:principal -> server:principal -> event_t
  | ServerAuthenticatedClient: client:principal -> server:principal -> cookie:cookie_t -> event_t
  | ClientReceivedCookie: client:principal -> server:principal -> cookie:cookie_t -> event_t

%splice [ps_event_t] (gen_parser (`event_t))
%splice [ps_event_t_is_well_formed] (gen_is_well_formed_lemma (`event_t))

instance event_login: event event_t = {
  tag = "LoginAPI.Event";
  format = mk_parseable_serializeable ps_event_t;
}


(*** HTTP Library Initialization ***)

instance http_config_login: http_config = {
  domain_to_principal = (fun domain -> (
    match domain with
    | ["dummyjson"; "com"] -> "Bob"
    | _ -> "Unknown")
  );
}


(*** API Functions ***)

val build_login_request:
  principal -> domain_t -> bytes ->
  (url_t kv_types & http_request_t web_types kv_types)
let build_login_request client domain password =
  let url:url_t kv_types = {
    protocol = HTTPS;
    domain = domain;
    port = 443;
    path = "/auth/login";
    query = [];
    fragment = {identifier = ""; data = []};
  } in
  let headers:list (header_t kv_types) = [
    UserAgent Server;
    ContentType "application/json";
  ] in
  let body = JSON [
    {key = "username"; value = VP client};
    {key = "password"; value = VB password}
  ] in
  let http_req = mk_http_request POST url headers body in
  (url, http_req)

val api_request: communication_keys_sess_ids -> principal -> state_id -> traceful (option (state_id & timestamp))
let api_request comm_keys_ids client sid =
  let*? st = get_state client sid in
  guard_tr (InitialStateClient? st);*?
  let InitialStateClient domain password = st in
  
  let server = http_config_login.domain_to_principal domain in
  trigger_event client (ClientAuthenticatesToServer client server);*

  let (url, http_req) = build_login_request client domain password in
  let*? (msg_id, hmeta_data) = send_https_request comm_keys_ids client url http_req in
  
  let* sid = new_session_id client in
  set_state client sid (SendRequest hmeta_data);*
  return (Some (sid, msg_id))

val login_request_credentials_match:
  principal -> bytes -> http_request_t web_types kv_types -> bool
let login_request_credentials_match client password http_req =
  match get_principal_from_json_encoded "username" http_req.body,
        get_bytes_from_json_encoded "password" http_req.body with
  | Some client', Some password' -> client = client' && password = password'
  | _ -> false

val build_login_response: principal -> cookie_t -> http_response_t web_types kv_types
let build_login_response client cookie =
  let headers:list (header_t kv_types) = [
    ContentType "application/json";
    SetCookie cookie
  ] in
  let body = JSON [{
    key = "id"; value = VI 1 };
    {key = "username"; value = VS client};
    {key =  "email"; value = VS "emily.johnson@x.dummyjson.com"};
    {key = "firstName"; value = VS "Emily"};
    {key = "lastName"; value = VS "Johnson"}
  ] in
  mk_http_response 200 headers body

val api_server: communication_keys_sess_ids -> principal -> state_id -> timestamp -> traceful (option timestamp)
let api_server comm_keys_ids server sid msg_id =
  let*? st = get_state server sid in
  guard_tr (InitialStateServer? st);*?
  let InitialStateServer client password = st in

  let*? (http_req, hmeta_data) = receive_https_request comm_keys_ids server msg_id in
  guard_tr (get_user_agent_header http_req.headers = Some Server);*?
  guard_tr (login_request_credentials_match client password http_req);*?

  let*? cookie_value = mk_comm_layer_response_nonce hmeta_data NoUsage in
  let cookie = {
    name = "accessToken";
    value = cookie_value;
    http_only = true;
    secure = true;
  } in

  trigger_event server (ServerAuthenticatedClient client server cookie);*

  let http_resp = build_login_response client cookie in
  let*? msg_id_out = send_https_response server hmeta_data http_resp in
  return (Some msg_id_out)

val process_login_response:
  client:principal -> http_response_t web_types kv_types -> option cookie_t
let process_login_response client http_res =
  let? id = get_int_from_json_encoded "id" http_res.body in
  let _ = IO.debug_print_string (Printf.sprintf "\nReceived id: %d\n" id) in
  let? username = get_string_from_json_encoded "username" http_res.body in
  let _ = IO.debug_print_string (Printf.sprintf "Received username: %s\n" username) in
  guard (username = client);?
  let? email = get_string_from_json_encoded "email" http_res.body in
  let _ = IO.debug_print_string (Printf.sprintf "Received email: %s\n" email) in
  let? firstName = get_string_from_json_encoded "firstName" http_res.body in
  let _ = IO.debug_print_string (Printf.sprintf "Received firstName: %s\n" firstName) in
  let? lastName = get_string_from_json_encoded "lastName" http_res.body in
  let _ = IO.debug_print_string (Printf.sprintf "Received lastName: %s\n\n" lastName) in
  let? cookie = get_set_cookie_header "accessToken" http_res.headers in
  guard (cookie.secure);?
  let _ = IO.debug_print_string (Printf.sprintf "Received cookie: %s\n" (bytes_to_string cookie.value)) in
  Some cookie

val api_response: principal -> state_id -> timestamp -> traceful (option unit)
let api_response client sid msg_id =
  let*? st = get_state client sid in
  guard_tr (SendRequest? st);*?
  let SendRequest hmeta_data = st in
  let*? http_res = receive_https_response hmeta_data client msg_id in
  let*? cookie = return (process_login_response client http_res) in
  guard_tr (cookie.secure);*?
  trigger_event client (ClientReceivedCookie client hmeta_data.server cookie);*
  return (Some ())
