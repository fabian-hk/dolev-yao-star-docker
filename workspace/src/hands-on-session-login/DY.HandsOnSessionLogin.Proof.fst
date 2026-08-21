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
  let (_, tr_out) = api_server comm_keys_ids server sid msg_id tr in
  
  let (opt_state, tr_get) = get_state #state_t server sid tr in
  assert(trace_invariant tr_get);
  match opt_state with
  | None -> ()
  | Some st ->
    let (guarded, tr_gd1) = guard_tr (InitialStateServer? st) tr_get in
    assert(trace_invariant tr_gd1);
    match guarded with
    | None -> ()
    | Some _ ->
      let InitialStateServer client password = st in

      let (opt_request, tr_received) = receive_https_request comm_keys_ids server msg_id tr_get in
      receive_https_request_proof #protocol_invariants_login #web_types #kv_types tr_get comm_keys_ids server msg_id;
      assert(trace_invariant tr_received);
      match opt_request with
      | None -> ()
      | Some (http_req, hmeta_data) ->
        let (opt_user_agent, tr_gd2) = guard_tr (get_user_agent_header http_req.headers = Some Server) tr_received in
        assert(trace_invariant tr_gd2);
        match opt_user_agent with
        | None -> ()
        | Some _ ->
          let (credentials_match, tr_gd3) = guard_tr (login_request_credentials_match client password http_req) tr_gd2 in
          assert(trace_invariant tr_gd3);
          match credentials_match with
          | None -> ()
          | Some _ ->
            let (opt_cookie, tr_nonce) = mk_comm_layer_response_nonce hmeta_data NoUsage tr_gd3 in
            assert(trace_invariant tr_nonce);
            match opt_cookie with
            | None -> ()
            | Some cookie_value ->
              let cookie = {
                name = "accessToken";
                value = cookie_value;
                http_only = true;
                secure = true;
              } in
              let ((), tr_event) = trigger_event server (ServerAuthenticatedClient client server cookie) tr_nonce in
              helper_lemma_event_invariant_server_authenticated_client tr_nonce client server http_req hmeta_data password cookie;
              assert(trace_invariant tr_event);
              
              let http_resp = build_login_response client cookie in
              let (_, tr_snd) = send_https_response server hmeta_data http_resp tr_event in
              
              assert_norm(Some? (get_set_cookie_header "accessToken" [SetCookie cookie <: header_t kv_types]));
              build_login_response_proof tr_event hmeta_data client cookie;
              send_https_response_proof tr_event server hmeta_data http_resp;
              assert(trace_invariant tr_snd);
              assert (tr_snd == tr_out);
              ()
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
  let (_, tr_out) = api_response client sid msg_id tr in

  let (opt_state, tr_get) = get_state #state_t client sid tr in
  assert(trace_invariant tr_get);
  match opt_state with
  | None -> ()
  | Some st ->
    let (guarded, tr_gd1) = guard_tr (SendRequest? st) tr_get in
    assert(trace_invariant tr_gd1);
    match guarded with
    | None -> ()
    | Some _ ->
      let SendRequest hmeta_data = st in
      let (opt_response, tr_received) = receive_https_response hmeta_data client msg_id tr_gd1 in
      receive_https_response_proof tr hmeta_data client msg_id;
      assert (trace_invariant tr_received);
      match opt_response with
      | None -> ()
      | Some http_res ->
        let (opt_cookie, tr_cookie) = return (process_login_response client http_res) tr_received in
        assert (trace_invariant tr_cookie);
        match opt_cookie with
        | None -> ()
        | Some cookie ->
          let (opt_gd, tr_gd2) = guard_tr (cookie.secure) tr_cookie in
          match opt_gd with
          | None -> ()
          | Some _ ->
            let ((), tr_event) = trigger_event client (ClientReceivedCookie client (hmeta_data.server) cookie) tr_gd2 in
            process_login_response_proof client http_res;
            helper_lemma_event_invariant_client_received_cookie tr_gd2 client hmeta_data http_res cookie;
            assert (trace_invariant tr_event);
            assert (tr_event == tr_out);
            ()
#pop-options
