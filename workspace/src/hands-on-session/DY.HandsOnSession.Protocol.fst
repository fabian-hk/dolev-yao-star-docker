module DY.HandsOnSession.Protocol

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

(* 1. Define and setup state *)

(* 2. Implement client send request and set state function *)
val api_request: communication_keys_sess_ids -> principal -> traceful (option (state_id & timestamp))
let api_request comm_keys_ids client =

  return (Some (({the_id=0} <: state_id), (0 <: timestamp))) // TODO replace with actual values, e.g. return (Some (sid, msg_id))

(* 3. Implement server function that receives the request and sends a response *)
val api_server: communication_keys_sess_ids -> principal -> timestamp -> traceful (option timestamp)
let api_server comm_keys_ids server msg_id =

  return (Some (0 <: timestamp)) // TODO replace with actual values, e.g. return (Some msg_id_out)

(* 4. Implement client receive response and print result function *)
val api_response: principal -> state_id -> timestamp -> traceful (option unit)
let api_response client sid msg_id =

  return (Some ())
