module DY.Login.SecurityProperties

open Comparse
open FStar.List.Tot { for_allP }
open DY.Core
open DY.Lib

open DY.Lib.Web
open DY.Lib.Web.HTTP.Invariants
open DY.Lib.Web.Data.Default.Invariants

open DY.Login.Protocol
open DY.Login.Invariants

#set-options "--fuel 0 --ifuel 0 --z3cliopt 'smt.qi.eager_threshold=100'"

val user_authentication:
  tr:trace -> client:principal -> server:principal -> cookie:cookie_t ->
  Lemma
  (requires
    trace_invariant tr /\
    event_triggered tr server (ServerAuthenticatedClient client server cookie)
  )
  (ensures (
    event_triggered tr client (ClientAuthenticatesToServer client server) \/
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  ))
let user_authentication tr client server cookie = ()

val server_authentication:
  tr:trace -> client:principal -> server:principal -> cookie:cookie_t ->
  Lemma
  (requires
    trace_invariant tr /\
    event_triggered tr client (ClientReceivedCookie client server cookie)
  )
  (ensures (
    event_triggered tr server (ServerAuthenticatedClient client server cookie) \/
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  ))
let server_authentication tr client server cookie = ()

val password_secrecy:
  tr:trace -> client:principal -> server:principal -> password:bytes ->
  Lemma
  (requires
    trace_invariant tr /\
    attacker_knows tr password /\ (
      (exists sess_id. state_was_set tr client sess_id (InitialState client server password)) \/
      (exists sess_id. state_was_set tr server sess_id (InitialState client server password))
    )
  )
  (ensures
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  )
let password_secrecy tr client server password =
  attacker_only_knows_publishable_values tr password

val cookie_secrecy:
  tr:trace -> client:principal -> server:principal -> cookie:cookie_t ->
  Lemma
  (requires
    trace_invariant tr /\
    attacker_knows tr cookie.value /\ (
      event_triggered tr server (ServerAuthenticatedClient client server cookie) \/
      event_triggered tr client (ClientReceivedCookie client server cookie)
    )
  )
  (ensures
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  )
let cookie_secrecy tr client server cookie =
  attacker_only_knows_publishable_values tr cookie.value