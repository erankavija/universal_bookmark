(*
  Reproducible ddot: Coq proof starter

  Goal:
  - Specify the mathematical semantics of ddot (real numbers, exact products, final rounding).
  - Specify the superaccumulator semantics as an integer sum scaled by 2^EMIN.
  - State key lemmas to prove:
      1) Update correctness per term (decode -> exact S,E; product exact; accumulator update exact).
      2) Order independence (commutativity/associativity on the accumulator structure).
      3) Finalization: correct nearest-even rounding to IEEE-754 double (normal and subnormal).
  - Later: mechanize with Flocq for IEEE semantics and VST for C refinement.
*)

Require Import Coq.ZArith.ZArith.
Require Import Coq.Lists.List.
Require Import Coq.Reals.Reals.
Require Import Lia.
Import ListNotations.

Module ReproDot.

(* Constants mirroring the C implementation *)
Definition EMIN : Z := -2148%Z.

(* Abstract representation of an input double.
   For the proof starter, we avoid IEEE bit-level details and model
   decode_double_SE as an abstract function that yields:
     - either a special (NaN, +/-Inf), or
     - a finite decomposition: sign s ∈ {-1, +1}, integer significand S ≥ 0, exponent E ∈ Z,
       with |value| = S * 2^E (exact), and S=0 implies value=0.
   Later, connect to Flocq's bit-level formalization. *)

Inductive special :=
| SNaN
| SInf (sgn: Z). (* sgn = +1 or -1 *)

Record finite_SE := {
  f_sign : Z;       (* -1 or +1 *)
  f_S : Z;          (* integer significand, >= 0 *)
  f_E : Z           (* exponent, any integer; for zeros, f_S = 0 *)
}.

Inductive fclass :=
| FC_special (sp: special)
| FC_finite (f: finite_SE).

(* Abstract decode function for a double to fclass. *)
Parameter decode_double_SE : R -> fclass.

Axiom decode_SE_finite_sound :
  forall (d: R) (f: finite_SE),
    decode_double_SE d = FC_finite f ->
    (f.(f_S) >= 0)%Z /\
    ((f.(f_sign) = 1)%Z \/ (f.(f_sign) = -1)%Z) /\
    (d = IZR (f.(f_sign)) * (IZR f.(f_S)) * powerRZ 2 f.(f_E))%R.

Axiom decode_SE_special_sound :
  forall (d: R) (sp: special),
    decode_double_SE d = FC_special sp ->
    True. (* Placeholder: later, relate to IEEE-754 R (Flocq) classification *)

(* Exact dot product over reals (mathematical spec) *)
Fixpoint dotR (x y: list R) : R :=
  match x, y with
  | [], [] => 0%R
  | a::xs, b::ys => (a * b + dotR xs ys)%R
  | _, _ => 0%R (* lengths mismatch: define as 0 for convenience *)
  end.

(* Superaccumulator model:
   We represent the accumulator as a single integer A such that
     A = sum_i ( s_i * Sx_i * Sy_i * 2^(Ex_i + Ey_i - EMIN) )
   where (s_i,Sx_i,Ex_i) and (s_i,Sy_i,Ey_i) are the finite decodings.
   This mirrors the C code's big-integer that stores the value scaled by 2^EMIN.
*)

Definition term_int (fx fy: finite_SE) : Z :=
  (fx.(f_sign) * fy.(f_sign) * fx.(f_S) * fy.(f_S))%Z.

Definition term_shift (fx fy: finite_SE) : Z :=
  (fx.(f_E) + fy.(f_E) - EMIN)%Z.

(* An accumulator is just a big integer A ∈ Z in the spec. *)
Definition acc := Z.

Definition acc_empty : acc := 0%Z.

(* Update: add Sprod << shift, i.e., Sprod * 2^(shift) *)
Definition acc_update (A: acc) (fx fy: finite_SE) : acc :=
  (A + term_int fx fy * Z.pow 2 (term_shift fx fy))%Z.

(* Order independence holds by commutativity of + over Z *)
Lemma acc_update_comm :
  forall A f1 f2,
    acc_update (acc_update A f1 f2) f2 f1 =
    acc_update (acc_update A f2 f1) f1 f2.
Proof.
  intros. unfold acc_update, term_int, term_shift. lia.
Qed.

(* Accumulating a list of pairs *)
Fixpoint acc_fold (A: acc) (xs ys: list finite_SE) : acc :=
  match xs, ys with
  | [], [] => A
  | fx::tx, fy::ty => acc_fold (acc_update A fx fy) tx ty
  | _, _ => A
  end.

(* Soundness: If all inputs are finite (no NaN/Inf), then the real sum equals
   A * 2^EMIN, i.e., value = (A * 2^EMIN) in reals. *)
Theorem acc_fold_sound :
  forall (xs ys: list R) (fxs fys: list finite_SE),
    length xs = length ys ->
    (forall i xi yi,
        nth_error xs i = Some xi ->
        nth_error ys i = Some yi ->
        exists fx fy,
          decode_double_SE xi = FC_finite fx /\
          decode_double_SE yi = FC_finite fy /\
          nth_error fxs i = Some fx /\
          nth_error fys i = Some fy) ->
    (* Value of dotR equals the scaled integer sum *)
    let A := acc_fold acc_empty fxs fys in
    dotR xs ys =
    ((IZR A) * powerRZ 2 EMIN)%R (* Z * 2^EMIN *).
Proof.
  (* Sketch:
     - Use decode_SE_finite_sound to rewrite each xi, yi into s*S*2^E.
     - dotR xs ys expands into Σ s_i * S_i * 2^(E_i) * s'_i * S'_i * 2^(E'_i).
     - Factor out 2^EMIN and show the integer sum equals A by induction.
     - Details and indexing omitted; this is a placeholder theorem to refine.
  *)
Admitted.

(* Finalization and rounding:
   Define a function that maps the integer accumulator A back to IEEE-754 double
   with nearest-even rounding (including subnormal/overflow to Inf).
   For the starter, we abstract it as a function round_to_double(A) and
   impose correctness axioms that match the C code's behavior.
*)

Parameter round_to_double : Z -> R.

Axiom round_to_double_correct :
  forall (A: Z), True.
  (* TODO:
     - Use Flocq to show that rounding nearest-even of (A * 2^EMIN) to double
       matches IEEE-754 rounding, including subnormals and overflow to +/-Inf.
  *)

(* End-to-end (finite case, no exceptions): *)
Theorem ddot_repro_finite_correct :
  forall xs ys fxs fys,
    length xs = length ys ->
    (forall i xi yi,
        nth_error xs i = Some xi ->
        nth_error ys i = Some yi ->
        exists fx fy,
          decode_double_SE xi = FC_finite fx /\
          decode_double_SE yi = FC_finite fy /\
          nth_error fxs i = Some fx /\
          nth_error fys i = Some fy) ->
    let A := acc_fold acc_empty fxs fys in
    (* C's result equals round_to_double(A), which equals correctly rounded dotR *)
    round_to_double A = dotR xs ys.
Proof.
  (* Combine acc_fold_sound with round_to_double correctness.
     This is a high-level statement to refine once Flocq/VST are in place. *)
Admitted.

(* Exceptional cases:
   - If any NaN or invalid 0*Inf occurs, result is NaN.
   - If both +Inf and -Inf contributions, result is NaN.
   - Otherwise, +Inf or -Inf if only one sign of infinity is present.
   We leave these as separate predicates/axioms to be connected to bit-level decode later.
*)

End ReproDot.
