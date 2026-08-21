module DY.HandsOnSessionLogin.Protocol

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

(*
  DY* model describing a client login at:
  https://dummyjson.com/auth/login
*)

(* 1. Define and setup state *)

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


(* 2. Define and setup events *)


(* 3. Setup HTTP library *)


(*** API Functions ***)

(* 3. Implement client send request:
  - Load initial state
  - Trigger client authenticates event
  - Build and send HTTPS request
  - Save state with request metadata
 *)

val api_request: communication_keys_sess_ids -> principal -> state_id -> traceful (option (state_id & timestamp))
let api_request comm_keys_ids client sid =
  return (Some (({the_id=0} <: state_id), (0 <: timestamp))) // TODO replace with actual values, e.g. return (Some (sid, msg_id))


(* 4. Implement server:
  - Load initial state
  - Receive HTTPS request
  - Create session cookie
  - Trigger server authenticated client event
  - Build and send HTTPS response
 *)

val api_server: communication_keys_sess_ids -> principal -> state_id -> timestamp -> traceful (option timestamp)
let api_server comm_keys_ids server sid msg_id =
  return (Some (0 <: timestamp)) // TODO replace with actual values, e.g. return (Some msg_id_out)


(* 4. Implement server:
  - Load send request state
  - Receive HTTPS response
  - Parse, validate, and print response
  - Trigger client received cookie event
 *)

val api_response: principal -> state_id -> timestamp -> traceful (option unit)
let api_response client sid msg_id =
  return (Some ())
