module DY.PotterAPI.Protocol

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

(*
  DY* model describing a client interaction with the
  Potter API endpoint:
  https://potterapi-fedeperin.vercel.app/en/spells/random
*)

(*** Protocol State Definition ***)

[@@with_bytes bytes]
type state_t =
  | SendRequest: http_meta_data web_types kv_types -> state_t

%splice [ps_state_t] (gen_parser (`state_t))
%splice [ps_state_t_is_well_formed] (gen_is_well_formed_lemma (`state_t))

instance parseable_serializeable_bytes_state_t: parseable_serializeable bytes state_t
  = mk_parseable_serializeable ps_state_t

instance local_state_state_t: local_state state_t = {
  tag = "PotterAPI.State";
  format = parseable_serializeable_bytes_state_t;
}


(*** HTTP Library Initialization ***)

instance http_config_cat_fact_api: http_config = {
  domain_to_principal = (fun domain -> (
    match domain with
    | ["potterapi-fedeperin"; "vercel"; "app"] -> "Bob"
    | _ -> "Unknown")
  );
}


(*** API Functions ***)

val api_request: communication_keys_sess_ids -> principal -> traceful (option (state_id & timestamp))
let api_request comm_keys_ids client =
  let u:url_t kv_types = {
    protocol = HTTPS;
    domain = ["potterapi-fedeperin"; "vercel"; "app"];
    port = 443;
    path = "/en/spells/random";
    query = [];
    fragment = {identifier = ""; data = []};
  } in
  let headers = [
    Accept "application/json";
  ] in
  let http_req = mk_http_request GET u headers empty_body in
  let*? (msg_id, hmeta_data) = send_https_request comm_keys_ids client u http_req in

  let* sid = new_session_id client in
  set_state client sid (SendRequest hmeta_data);*
  return (Some (sid, msg_id))

val api_server: communication_keys_sess_ids -> principal -> timestamp -> traceful (option timestamp)
let api_server comm_keys_ids server msg_id =
  let*? (http_req, hmeta_data) = receive_https_request comm_keys_ids server msg_id in
  let headers:list (header_t kv_types) = [ContentType "application/json"] in
  let body = JSON [{key = "spell"; value = VS "Prior Incantato" }; {key = "use"; value = VS "Reveals last spell cast" }; {key =  "index"; value = VI 29}] in
  let http_res = mk_http_response 200 headers body in
  let*? msg_id_out = send_https_response server hmeta_data http_res in
  return (Some msg_id_out)

val api_response: principal -> state_id -> timestamp -> traceful (option unit)
let api_response client sid msg_id =
  let*? SendRequest hmeta_data = get_state client sid in
  let*? http_res = receive_https_response hmeta_data client msg_id in
  let*? spell = return (get_string_from_json_encoded "spell" http_res.body) in
  let _ = IO.debug_print_string (Printf.sprintf "\nReceived spell: %s\n" spell) in
  let*? use = return (get_string_from_json_encoded "use" http_res.body) in
  let _ = IO.debug_print_string (Printf.sprintf "Spell use: %s\n" use) in
  let*? index = return (get_int_from_json_encoded "index" http_res.body) in
  let _ = IO.debug_print_string (Printf.sprintf "Spell index: %d\n\n" index) in
  return (Some ())
