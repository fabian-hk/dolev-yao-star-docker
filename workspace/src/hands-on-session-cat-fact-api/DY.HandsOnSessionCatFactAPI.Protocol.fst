module DY.HandsOnSessionCatFactAPI.Protocol

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

(*
  DY* model describing a client interaction with the
  CatFact API endpoint:
  https://catfact.ninja/fact?max_length=140
*)

(* 1. Define and setup state *)

[@@with_bytes bytes]
type state_t =
  | SendRequest: http_meta_data web_types kv_types -> state_t

%splice [ps_state_t] (gen_parser (`state_t))
%splice [ps_state_t_is_well_formed] (gen_is_well_formed_lemma (`state_t))

instance parseable_serializeable_bytes_state_t: parseable_serializeable bytes state_t
  = mk_parseable_serializeable ps_state_t

instance local_state_state_t: local_state state_t = {
  tag = "CatFactAPI.State";
  format = parseable_serializeable_bytes_state_t;
}


(* 2. Setup HTTP library *)

instance http_config_cat_fact_api: http_config = {
  domain_to_principal = (fun domain -> (
    match domain with
    | ["catfact"; "ninja"] -> "Bob"
    | _ -> "Unknown")
  );
}


(*** API Functions ***)

(* 3. Implement client send request and set state function *)
val api_request: communication_keys_sess_ids -> principal -> traceful (option (state_id & timestamp))
let api_request comm_keys_ids client =
  return (Some (({the_id=0} <: state_id), (0 <: timestamp))) // TODO replace with actual values, e.g. return (Some (sid, msg_id))

(* 4. Implement server function that receives the request and sends a response *)
val api_server: communication_keys_sess_ids -> principal -> timestamp -> traceful (option timestamp)
let api_server comm_keys_ids server msg_id =
  return (Some (0 <: timestamp)) // TODO replace with actual values, e.g. return (Some msg_id_out)

(* 5. Implement client receive response and print result function *)
val api_response: principal -> state_id -> timestamp -> traceful (option unit)
let api_response client sid msg_id =
  return (Some ())
