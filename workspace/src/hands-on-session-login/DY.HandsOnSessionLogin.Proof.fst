module DY.HandsOnSessionLogin.Proof

open Comparse
open FStar.List.Tot { for_allP }
open DY.Core
open DY.Lib

open DY.Lib.Web
open DY.Lib.Web.HTTP.Invariants
open DY.Lib.Web.Data.Default.Invariants

open DY.HandsOnSessionLogin.Protocol
open DY.HandsOnSessionLogin.Invariants
open DY.HandsOnSessionLogin.Proof.Helpers

#set-options "--fuel 0 --ifuel 0 --z3cliopt 'smt.qi.eager_threshold=100'"
(*
(*** API Request ***)

// 1. Prove that the api_request function preserves the trace invariant


(*** API Server ***)

// 2. Prove that the api_server function preserves the trace invariant
#restart-solver
#push-options "--ifuel 1 --z3rlimit 100"
val api_server_proof:
  tr:trace -> comm_keys_ids:communication_keys_sess_ids ->
  server:principal -> sid:state_id -> msg_id:timestamp ->
  Lemma
  (requires
    trace_invariant tr
  )
  (ensures (
    let (_, tr_out) = api_server comm_keys_ids server sid msg_id tr in
    trace_invariant tr_out
  ))
let api_server_proof tr comm_keys_ids server sid msg_id =
  admit()
#pop-options


(*** API Response ***)

// 3. Prove that the api_response function preserves the trace invariant
#restart-solver
#push-options "--ifuel 1 --z3rlimit 50"
val api_response_proof:
  tr:trace -> client:principal -> sid:state_id -> msg_id:timestamp ->
  Lemma
  (requires
    trace_invariant tr
  )
  (ensures (
    let (_, tr_out) = api_response client sid msg_id tr in
    trace_invariant tr_out
  ))
let api_response_proof tr client sid msg_id =
  admit()
#pop-options
