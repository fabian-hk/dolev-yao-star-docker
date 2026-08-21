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

#set-options "--fuel 0 --ifuel 0 --z3cliopt 'smt.qi.eager_threshold=100'"

(*** API Request ***)

#push-options "--fuel 4 --z3rlimit 40"
val build_login_request_proof:
  tr:trace -> client:principal -> domain:domain_t -> password:bytes ->
  Lemma
  (requires (
    let server = domain_to_principal domain in
    is_secret (comm_label client server) tr password /\
    event_triggered tr client (ClientAuthenticatesToServer client server)
  ))
  (ensures (
    let (url, http_req) = build_login_request client domain password in
    let server = domain_to_principal url.domain in
    domain_to_principal domain == server /\
    get_user_agent_header http_req.headers == Some Server /\
    http_query_predicates_login.http_query_pred tr client server http_req (comm_label client server) /\
    http_request_headers_properties tr client server http_req (comm_label client server) /\
    body_preds_web_types.http_body_request_pred tr client server http_req (comm_label client server) /\
    is_well_formed (http_request_t web_types kv_types) (is_knowable_by (comm_label client server) tr) http_req /\
    is_server_request http_req
  ))
let build_login_request_proof tr client domain password =
  reveal_opaque (`%build_login_request) build_login_request;
  let url:url_t kv_types = {
    protocol = HTTPS;
    domain = domain;
    port = 443;
    path = "/auth/login";
    query = [];
    fragment = {identifier = ""; data = []};
  } in
  let server = domain_to_principal url.domain in
  let lab = comm_label client server in
  let headers:list (header_t kv_types) = [
    UserAgent Server;
    ContentType "application/json"
  ] in
  let json_lst = [
    {key = "username"; value = VP client};
    {key = "password"; value = VB password}
  ] in
  let body = JSON json_lst in
  let http_req = mk_http_request POST url headers body in
  mk_http_request_body_eq POST url headers body;
  mk_http_request_query_eq POST url headers body;
  mk_http_request_headers_extractable tr POST url headers body;

  assert(is_server_request http_req);

  assert (
    wt_send_request_pred_key_username.pred
      tr client server lab http_req
  );
  assert (
    wt_send_request_pred_key_password.pred
      tr client server lab http_req
  );
  web_types_request_key_pred_implies_global_pred
    tr "username" wt_send_request_pred_key_username client server http_req;
  web_types_request_key_pred_implies_global_pred
    tr "password" wt_send_request_pred_key_password client server http_req;
  assert (
    for_allP_web_types
      (web_types_predicates_login.wt_send_request_pred.pred
        tr client server lab http_req)
      body
  );
  forall_web_types_request_preds_implies_comm_reqres_preds_lemma
    tr client server url POST headers body;
  assert (is_knowable_by lab tr password);
  assert (for_allP (is_knowable_by_web_kv lab tr) (JSON?._0 body));
  web_types_serialization_lemma tr body lab;
  assert (for_allP (is_knowable_by_header lab tr) headers);
  assert (for_allP (is_knowable_by_key_value lab tr) url.query);
  mk_http_request_knowable tr client POST url headers body;
  ()
#pop-options

val helper_lemma_state_invariant_send_request:
  tr:trace -> client:principal -> sid:state_id -> hmeta_data:http_meta_data web_types kv_types ->
  Lemma
  (requires (
    trace_invariant tr /\ 
    event_triggered tr client (CommClientSendRequest Unauthenticated client hmeta_data.server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types)) /\
    is_server_request (Request?.http_req hmeta_data.request)
  ))
  (ensures (
    state_predicate_login.pred tr client sid (SendRequest hmeta_data)
  ))
let helper_lemma_state_invariant_send_request tr client sid hmeta_data = ()

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
  reveal_opaque (`%api_request) (api_request comm_keys_ids client sid);
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

#restart-solver
#push-options "--fuel 6 --z3rlimit 40"
val build_login_response_proof:
  tr:trace -> hmeta_data:http_meta_data web_types kv_types ->
  client:principal -> cookie:cookie_t ->
  Lemma
  (requires
    event_triggered tr hmeta_data.server (ServerAuthenticatedClient client hmeta_data.server cookie) /\
    is_secret (get_response_label tr hmeta_data) tr cookie.value /\
    cookie.secure == true /\
    Some? (get_set_cookie_header "accessToken" [SetCookie cookie <: header_t kv_types])
  )
  (ensures (
    let http_res = build_login_response client cookie in
    let http_req = Request?.http_req hmeta_data.request in
    is_well_formed (http_response_t web_types kv_types) (is_knowable_by (get_response_label tr hmeta_data) tr) http_res /\
    body_preds_web_types.http_body_response_pred tr hmeta_data.client hmeta_data.server http_req http_res (get_response_label tr hmeta_data) /\
    http_response_properties tr hmeta_data.client hmeta_data.server http_req http_res (get_response_label tr hmeta_data)
  ))
let build_login_response_proof tr hmeta_data client cookie =
  reveal_opaque (`%build_login_response) build_login_response;
  let headers:list (header_t kv_types) = [
    ContentType "application/json";
    SetCookie cookie
  ] in
  let body = JSON [
    {key = "id"; value = VI 1};
    {key = "username"; value = VS client};
    {key = "email"; value = VS "emily.johnson@x.dummyjson.com"};
    {key = "firstName"; value = VS "Emily"};
    {key = "lastName"; value = VS "Johnson"}
  ] in
  let http_res = mk_http_response 200 headers body in
  let http_req = Request?.http_req hmeta_data.request in
  
  // Proving is_well_formed
  let lab = get_response_label tr hmeta_data in
  assert (for_allP (is_knowable_by_web_kv lab tr) (JSON?._0 body));
  web_types_serialization_lemma tr body lab;
  assert (for_allP (is_knowable_by_header lab tr) headers);
  mk_http_response_knowable tr hmeta_data.server hmeta_data 200 headers body;
  assert(is_well_formed (http_response_t web_types kv_types) (is_knowable_by lab tr) http_res);
  
  // Proving body_preds_web_types.http_body_response_pred
  web_types_response_key_pred_implies_global_pred tr "id" (wt_send_response_pred_key_true "id") hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "username" (wt_send_response_pred_key_username) hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "email" (wt_send_response_pred_key_true "email") hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "firstName" (wt_send_response_pred_key_true "firstName") hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "lastName" (wt_send_response_pred_key_true "lastName") hmeta_data http_req http_res;
  assert (for_allP_web_types (web_types_predicates_login.wt_send_response_pred.pred tr hmeta_data.server lab http_req http_res) body);
  forall_web_types_response_preds_implies_comm_reqres_preds_lemma tr hmeta_data 200 headers body;
  assert(body_preds_web_types.http_body_response_pred tr hmeta_data.client hmeta_data.server http_req http_res lab);
  
  // Proving http_response_properties
  assert(for_allP (http_response_header_properties tr hmeta_data.client hmeta_data.server http_req http_res lab) headers) by (
    let open FStar.Tactics in
    norm [delta_only [`%for_allP; `%http_response_header_properties]; iota; zeta];
    ()
  );
  mk_http_response_headers_extractable 200 headers body;
  assert(for_allP (http_response_header_properties tr hmeta_data.client hmeta_data.server http_req http_res lab) http_res.headers);
  assert(http_response_properties tr hmeta_data.client hmeta_data.server http_req http_res lab);
  ()
#pop-options

#push-options "--z3rlimit 20"
val helper_lemma_event_invariant_server_authenticated_client:
  tr:trace -> client:principal -> server:principal ->
  http_req:http_request_t web_types kv_types ->
  hmeta_data:http_meta_data web_types kv_types ->
  password:bytes ->
  cookie:cookie_t ->
  Lemma
  (requires
    trace_invariant tr /\
    hmeta_data.server == server /\
    hmeta_data.client == None /\
    hmeta_data.request == Request http_req /\
    event_triggered tr server (CommServerReceiveRequest hmeta_data.client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types)) /\
    get_bytes_from_json_encoded "password" http_req.body == Some password /\
    get_principal_from_json_encoded "username" http_req.body == Some client /\
    is_secret (comm_label client server) tr password /\
    is_server_request http_req /\
    is_secret (get_response_label tr hmeta_data) tr cookie.value
  )
  (ensures (
    event_predicate_login tr server (ServerAuthenticatedClient client server cookie)
  ))
let helper_lemma_event_invariant_server_authenticated_client tr client server http_req hmeta_data password cookie =
  eliminate (exists client. event_triggered tr client (CommClientSendRequest Unauthenticated client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))) \/
    (is_publishable tr hmeta_data.key /\ is_well_formed (http_t web_types kv_types) (is_publishable tr) hmeta_data.request)
  returns (event_triggered tr client (ClientAuthenticatesToServer client server) /\
        is_secret (comm_label client server) tr cookie.value) \/
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  with _. (
    eliminate exists client. event_triggered tr client (CommClientSendRequest Unauthenticated client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
    returns (event_triggered tr client (ClientAuthenticatesToServer client server) /\
        is_secret (comm_label client server) tr cookie.value) \/
      is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
    with _. (
      web_types_request_predicate tr "username" wt_send_request_pred_key_username hmeta_data client;
      get_response_label_eq_key_label tr hmeta_data;
      ()
    )
  )
  and _. (
    assert(is_well_formed web_types (is_publishable tr) http_req.body);
    get_bytes_from_json_encoded_knowable tr public "password" http_req.body;
    ()
  )
#pop-options

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
  reveal_opaque (`%api_server) (api_server comm_keys_ids server sid msg_id);
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

#restart-solver
#push-options "--z3rlimit 20"
val helper_lemma_event_invariant_client_received_cookie:
  tr:trace -> client:principal -> hmeta_data:http_meta_data web_types kv_types -> http_res:http_response_t web_types kv_types -> cookie:cookie_t ->
  Lemma
  (requires
    trace_invariant tr /\
    get_set_cookie_header "accessToken" http_res.headers == Some cookie /\
    get_string_from_json_encoded "username" http_res.body == Some client /\
    is_server_request (Request?.http_req hmeta_data.request) /\
    cookie.secure == true /\
    event_triggered tr client (CommClientReceiveResponse client (Response http_res) hmeta_data <: communication_reqres_event (http_t web_types kv_types)) /\
    event_triggered tr client (CommClientSendRequest (request_authenticated hmeta_data) client hmeta_data.server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
  )
  (ensures (
    event_predicate_login tr client (ClientReceivedCookie client hmeta_data.server cookie)
  ))
let helper_lemma_event_invariant_client_received_cookie tr client hmeta_data http_res cookie =
  response_message_properties tr client (Response http_res) hmeta_data;
  eliminate event_triggered tr hmeta_data.server (CommServerSendResponse hmeta_data.client hmeta_data.server hmeta_data.request (Response http_res) hmeta_data.key <: communication_reqres_event (http_t web_types kv_types)) \/
    (is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label hmeta_data.server))
  returns (event_triggered tr hmeta_data.server (ServerAuthenticatedClient client hmeta_data.server cookie) /\
        is_secret (comm_label client hmeta_data.server) tr cookie.value) \/
       is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label hmeta_data.server)
  with _. (
    let http_req = Request?.http_req hmeta_data.request in
    comm_server_send_response_implies_set_cookie_properties tr client hmeta_data http_res "accessToken" cookie;
    send_request_event_properties tr client hmeta_data;
    web_types_response_predicate tr "username" wt_send_response_pred_key_username hmeta_data client http_res;
    ()
  )
  and _. ()
#pop-options

#push-options "--ifuel 1 --z3rlimit 40"
val process_login_response_proof:
  client:principal -> http_res:http_response_t web_types kv_types -> 
  Lemma
  (ensures (
    let opt_cookie = process_login_response client http_res in
    match opt_cookie with
    | Some cookie -> get_set_cookie_header "accessToken" http_res.headers == Some cookie /\
      get_string_from_json_encoded "username" http_res.body == Some client /\
      cookie.secure == true
    | None -> True
  ))
let process_login_response_proof client http_res = ()
#pop-options

#push-options "--ifuel 1 --z3rlimit 40"
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
  reveal_opaque (`%api_response) (api_response client sid msg_id);
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
