module DY.HandsOnSession.Protocol

open Comparse
open DY.Core
open DY.Lib

open DY.Lib.Web

(* 1. Define and setup state *)

(* 2. Implement client send request and set state function *)
// val api_request: communication_keys_sess_ids -> principal -> principal -> traceful (option (state_id & timestamp))

(* 3. Implement server function that receives the request and sends a response *)
// val api_server: communication_keys_sess_ids -> principal -> timestamp -> traceful (option timestamp)

(* 4. Implement client receive response and print result function *)
// val api_response: principal -> state_id -> timestamp -> traceful (option unit)
