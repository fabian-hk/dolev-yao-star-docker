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

(*** API Request ***)

// 1. Prove that the api_request function preserves the trace invariant
#push-options "--ifuel 1 --z3rlimit 20"
val api_request_proof:
  tr:trace -> comm_keys_ids:communication_keys_sess_ids ->
  client:principal -> sid:state_id ->
  Lemma
  (requires
    trace_invariant tr
  )
  (ensures (
    let (_, tr_out) = api_request comm_keys_ids client sid tr in
    trace_invariant tr_out
  ))
let api_request_proof tr comm_keys_ids client sid =
  let (_, tr_out) = api_request comm_keys_ids client sid tr in

  let (opt_state, tr_get) = get_state #state_t client sid tr in
  assert(trace_invariant tr_get);
  match opt_state with
  | None -> ()
  | Some st ->
    let (guarded, tr_guard) = guard_tr (InitialStateClient? st) tr_get in
    assert(trace_invariant tr_guard);
    match guarded with
    | None -> ()
    | Some _ ->
      let InitialStateClient domain password = st in
      let server = http_config_login.domain_to_principal domain in
      let ((), tr_event) = trigger_event client (ClientAuthenticatesToServer client server) tr_guard in
      assert(trace_invariant tr_event);

      let (url, http_req) = build_login_request client domain password in
      let (opt_snd, tr_snd) = send_https_request comm_keys_ids client url http_req tr_event in
      build_login_request_proof tr_event client domain password;
      send_https_request_proof tr_event comm_keys_ids client url http_req;
      assert(trace_invariant tr_snd);
      match opt_snd with
      | None -> ()
      | Some (msg_id, hmeta_data) ->
        let (new_sid, tr_sid) = new_session_id client tr_snd in

        let ((), tr_st) = set_state client new_sid (SendRequest hmeta_data) tr_sid in
        helper_lemma_state_invariant_send_request tr_sid client new_sid hmeta_data;
        set_state_invariant state_predicate_login state_update_predicate_login client new_sid (SendRequest hmeta_data) tr_sid;
        assert(trace_invariant tr_st);

        assert(tr_st == tr_out);
        ()
#pop-options


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
