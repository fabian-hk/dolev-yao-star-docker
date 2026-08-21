module DY.HandsOnSessionLogin.SecurityProperties

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

// 1. Define user authentication property
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


// 2. Define cookie secrecy property
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