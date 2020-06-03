Set Warnings "-notation-overridden,-parsing".
From Coq Require Import Bool.Bool Init.Nat Arith.Arith Arith.EqNat
     Init.Datatypes Lists.List Strings.String Program.
Require Export Coq.Strings.String.
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype.
Import ListNotations.
(*basic list functions that I couldn't find in a library*)
Open Scope list_scope.
Fixpoint eq_lists {A: Type} (L1: list A) (L2: list A) (eq: A -> A -> Prop) :=
        match L1, L2 with
          nil, nil => True
        | (w::ws), (d::ds) => (eq w d) /\ (eq_lists ws ds eq) (*considers order*)
        | _ , _ => False end.

Fixpoint member {A: Type} (eq: A -> A -> bool) (a: A)  (L: list A) :=
  match L with
    [] => false
  | x::xs => orb (eq a x) (member eq a xs)
  end.

(*removes L1 from L2*)
Definition remove {A: Type} (in_A: A -> list A -> bool) (L1 L2 : list A) :=
  filter (fun x => negb (in_A x L1)) L2.

Definition prefix {A: Type} (O1: list A) (O2: list A) :=
  exists(l: nat), O1 = firstn l O2.

Close Scope list_scope.

Open Scope string_scope.
Lemma eqnat: Equality.axiom Init.Nat.eqb.
Proof.
  unfold Equality.axiom. intros.
  destruct (Init.Nat.eqb (x) (y)) eqn:beq.
  - constructor. apply beq_nat_true in beq. assumption.
  -  constructor. apply beq_nat_false in beq. assumption.
Qed.
Canonical nat_eqMixin := EqMixin eqnat.
Canonical nat_eqtype := Eval hnf in EqType nat nat_eqMixin.
(*---*)

(*setting up strings equality type*)
(* eqb_string and
eqb_string_true_iff taken from software foundations*)
Definition eqb_string (x y : string) : bool :=
  if string_dec x y then true else false.

Lemma eqb_string_true_iff : forall x y : string,
    eqb_string x y = true <-> x = y.
Proof.
   intros x y.
   unfold eqb_string.
   destruct (string_dec x y) as [H |Hs].
   - subst. split. reflexivity. reflexivity.
   - split.
     + intros contra. discriminate contra.
     + intros H. rewrite H in Hs *. destruct Hs. reflexivity.
Qed.
(*what is the star*)
Lemma eqstring: Equality.axiom eqb_string.
Proof.
  unfold Equality.axiom. intros.
  destruct (eqb_string x y) eqn:beq.
  - constructor. apply eqb_string_true_iff in beq. assumption.
  -  constructor. intros contra. apply eqb_string_true_iff in contra.
     rewrite contra in beq. discriminate beq.
Qed.
Canonical string_eqMixin := EqMixin eqstring.
Canonical string_eqtype := Eval hnf in EqType string string_eqMixin.
Close Scope string_scope.
(***)


(*Now, to business! Below is syntax*)
Open Scope type_scope.

Inductive boptype :=
  Plus
| Sub
| Mult
| Div
| Mod
| Or
| And.

(*shortcut!*)
Inductive value :=
    Nat (n: nat)
  | Bool (b: bool)
  | error. 
Coercion Bool : bool >-> value.
Coercion Nat : nat >-> value.

(*evaluation rules for binary operations*)

Fixpoint bopeval (bop: boptype) (v1 v2 :value): (value) :=
  match bop with
   Plus => 
    (
      match v1, v2 with
        (Nat n1), (Nat n2) => Nat (add n1 n2)
        | _, _ => error
        end
    )
  | Sub => 
    (
      match v1, v2 with
       (Nat n1), (Nat n2) => Nat (n1 - n2)
        | _, _ => error
        end
    )
  | Mult => 
    (
      match v1, v2 with
       (Nat n1), (Nat n2) => Nat (mul n1 n2)
        | _, _ => error
        end
    )
  | Div =>
    (
      match v1, v2 with
       (Nat n1), (Nat n2) =>
                    ( if (n2 == 0) then error
                      else Nat (n1 / n2))
        | _, _ => error
        end
    )
  | Mod =>
    (
      match v1, v2 with
       (Nat n1), (Nat n2) =>
                    ( if (n2 == 0) then error
                     else Nat (n1 mod n2))
        | _, _ => error
        end
    )
  | Or =>
  (
      match v1, v2 with
        (Bool b1), (Bool b2) => Bool (orb b1 b2)
        | _, _ => error
        end
    )
  | And =>
  (
      match v1, v2 with
        (Bool b1), (Bool b2) => Bool (andb b1 b2)
        | _, _ => error
        end
  )
  end.

(*value helper functions*)
Definition isvaluable (v: value) :=
  match v with
    error => False
  | _ => True
  end.

Definition isvalidbop (bop: boptype) (v1 v2 : value) :=
  match (bopeval bop v1 v2) with
    error => False
  | _ => True
   end.

Definition eqb_value (x y: value) :=
  match x, y with
    Nat nx, Nat ny => nx == ny
  | Bool bx, Bool byy => eqb bx byy
  | _, _ => false
  end.
Definition eq_value (x y: value) := is_true(eqb_value x y).

Definition eq_valueop (x y : option value) :=
  match x, y with
    Error, None => True
  | Some x1, Some y1 => eq_value x1 y1
  | _, _ => False
  end.

(*memory maps...used for both memories and checkpoints*)
Definition map (A: Type) (eqba: A -> A -> bool):= A -> value.

(*memory helpers*)
Definition emptymap A eqba :(map A eqba) := (fun _ => error).
Definition updatemap {A} {eqba} (m: map A eqba) (i: A) (v: value) : map A eqba := (fun j =>
                                                               if (eqba j i) then v
                                                               else (m j)).
Notation "i '|->' v ';' m" := (updatemap m i v)
  (at level 100, v at next level, right associativity).
(*in (m1 U! m2), m1 is checked first, then m2*)

Definition indomain {A} {eqba} (m: map A eqba) (x: A) :=
  match m x with
    error => False
  | _ => True
  end.
(*this function is NOT used to check the domain of checkpoint maps.
 In particular, because an entire array can be checkpointed even if only
 one element has been assigned to (while the other elements may, in theory, still be unassigned),
(in particular, I refer to D-WAR-CP-Arr)
this function would return that assigned array elements are in the domain of N, while the unassigned array
elements are not, even though both have been checkpointed.
 I resolved this problem by defining indomain_nvm, used for checkpoint maps in algorithms.v, which
checks if a warvar is in the domain, rather than checking a location.
 *)
(******************************************************************************************)

(*******************************more syntax**********************************************)
Inductive array :=
  Array (s: string) (l: nat).


Inductive volatility :=
  nonvol
 | vol.

Inductive exp :=
  Var (s: string) (q: volatility) 
| Val (v: value)
| Bop (bop: boptype) (e1: exp) (e2: exp) 
| El (a: array) (e: exp).
Coercion Val : value >-> exp.
Notation "a '[[' e ']]'" := (El (a) (e))
                            (at level 100, right associativity).
(*used subtypes to enforce the fact that only some expressions are
 memory locations*)
(*also made the write after read type easier*)
Definition smallvarpred := (fun x=> match x with
                                        Var _ _ => true
                                        | _ => false
                                 end).
Definition elpred  := (fun x=> match x with
                                        El (Array _ length) (Val (Nat i)) => (i <? length)
                                        | _ => false
                                 end).
(*note elpred checks if index is a natural in bounds*)
Notation smallvar := {x: exp | smallvarpred x}.
Notation el := {x: exp| elpred x}.
Definition loc := smallvar + el. (*memory location type*)

Definition warvar := smallvar + array. (*write after read variable type*)
Notation warvars := (list warvar).
(*Coercion (inl smallvar el): smallvar >-> loc.*)
(*Coercion inl: smallvar >-> loc.*)

(**location and warvar helper functions*)
(**no need to work directly with the subtypes or sumtypes, just use these**)
(**Note: some of these are currently unused due to implementation changes, but I left them
 as they might be useful later*)

(*array and el functions*)

(*checks name and length*)
Open Scope list_scope.
Definition eqb_array (a1 a2: array) :=
  match a1, a2 with
    Array s1 l1, Array s2 l2 => andb (s1 == s2) (l1 == l2)
    end.
Program Definition getarray (x: el): array :=
  match val x with
    El (arr) _ => arr
  | _ => !
  end.
Next Obligation. destruct (x) as [s| | |];
                 try (simpl in H0; discriminate H0).
     apply (H a e). reflexivity.
Qed.

Program Definition getindexel (x: el): value  :=
  match val x with
    El _ (Val v) => v
  | _ => !
  end.
Next Obligation. destruct (x) as [s| | |];
                 try (simpl in H0; discriminate H0).
                 destruct a eqn: adestruct.
                 destruct e;
                 try (simpl in H0; discriminate H0).
                 apply (H a v). subst. reflexivity.
Qed.

Definition samearray_b (element: el) (a: array) := (*checks if element indexes into a*)
  eqb_array (getarray element) a.

Definition samearray (element: el) (a: array) := is_true(samearray_b element a).

Definition el_arrayind_eq (e: el) (a: array) (vindex: value) := (*transitions from el type
                                                          to a[i] representation*)
  (samearray e a) /\ (eq_value (getindexel e) vindex).

(*smallvar functions*)
Definition isNV_b (x: smallvar) := (*checks if x is stored in nonvolatile memory*)
  match (val x) with
    Var _ nonvol => true
  | _ => false
  end.

Definition isV_b (x: smallvar) :=(*checks if x is stored in volatile memory*)
  match (val x) with
    Var _ vol => true
  | _ => false
  end.

Definition isNV x := is_true(isNV_b x). (*prop version of isNV_b*)

Definition isV x := is_true(isV_b x). (*prop version of isV_b*)

Definition samevolatility_b (x y: smallvar) := (*used for defining equality of memory locations*)
  match isNV_b(x), isNV_b(y) with
    true, true => true
  | false, false => true
  | _, _ => false
  end.

Program Definition getstringsv (x: smallvar): string :=
  match val x with
    Var s _ => s
  | _ => !
  end. 
Next Obligation.
    destruct x as [s| | |];
      try (simpl in H0; discriminate H0). apply (H s q). reflexivity.
Qed.

Definition eqb_smallvar (x y: smallvar): bool :=
  andb ((getstringsv x)==(getstringsv y)) (samevolatility_b x y).

(*loc and warvar functions*)

Definition eqb_warvar (w1 w2: warvar) :=
  match w1, w2 with
               inl x, inl y => eqb_smallvar x y
             | inr x, inr y => eqb_array x y
             | _, _ => false
  end.

Definition eq_warvar (w1 w2: warvar) :=
  is_true (eqb_warvar w1 w2).

(*checks if w was recorded as read/written to in warvar list W*)
Notation memberwv_wv_b := (member eqb_warvar).

Definition memberwv_wv (w: warvar) (W: warvars) := is_true(memberwv_wv_b w W).


Definition eqb_loc (l1: loc) (l2: loc) :=
  match l1, l2 with
    inl x, inl y => eqb_smallvar x y
  | inr x, inr y => andb (eqb_array (getarray x) (getarray y))
                        (eqb_value (getindexel x) (getindexel y))
  | _, _ => false 
  end. (*might be nice to have values as an equality type here*)

Notation in_loc_b := (member eqb_loc).

(*converts a location to a warvar*)
Fixpoint loc_warvar (l: loc) : warvar := 
  match l with
    inl x => inl x
  | inr el => inr (getarray el)
  end.


(*checks if a location input has been stored as a WAR location in w*)
Definition memberloc_wvs_b (input: loc) (w: warvars) :=
  memberwv_wv_b (loc_warvar input) w.
(*******************************************************************)

(*more syntax*)
Inductive instruction :=
  skip
| asgn_sv (x: smallvar) (e: exp) (*could distinguish between NV and V assignments as well here*)
| asgn_arr (a: array) (i: exp) (e: exp) (*i is index, e is new value of a[i]*)
| incheckpoint (w: warvars)
| inreboot.
(*added the in prefixes to distinguish from the observation reboots
 and checkpoints*)

Inductive command :=
  Ins (l: instruction)
| Seqcom (l: instruction) (c: command) (*added suffix to distinguish from Seq ceval
                                         constructor*)
| ITE (e: exp) (c1: command) (c2: command).

Notation "l ';;' c" := (Seqcom l c)
                         (at level 100).

Notation "'TEST' e 'THEN' c1 'ELSE' c2 " := (ITE e c1 c2)
                                              (at level 100).
Coercion Ins : instruction >-> command.
(*******************************************************************)

(******setting up location equality relation for memory maps******************)
(****************************************************************)

(****************************memory*************************************)

(*memory locations defined above warvars*)
Notation mem := (map loc eqb_loc). (*memory mapping*)

Inductive nvmem := (*nonvolatile memory*)
  NonVol (m : mem) (D: warvars). (*extra argument to keep track of checkpointed warvars because
                                  it might be nice to have for when we do checkpoint proofs*)

Inductive vmem := (*volatile memory*)
  Vol (m : mem).

(*I could change nvmem and vmem to enforce that they only take in smallvars
 of the correct type but it's already checked in my evaluation rules*)

(**************************helpers for the memory maps*********************************************)

(*note: a lot of these aren't being used right now because, after I changed the types
 of DINO and WAR, they aren't necessary.
 I won't delete them because having the domain of the checkpoint easily accessible and
 manipulable could be handy in the future*)

Definition getmap (N: nvmem) :=
  match N with NonVol m _ => m end.

Definition getdomain (N: nvmem) :=
  match N with NonVol _ D => D end.

Definition getvalue (N: nvmem) (i: loc) :=
  (getmap N) i.
  Notation "v '<-' N" := (getvalue N v)
                           (at level 40).


  (*updates domain and mapping function*)
Definition updateNV (N: nvmem) (i: loc) (v: value) :=
  match N with NonVol m D =>
               NonVol (updatemap m i v) (
                        match i with 
                          inl x => ((inl x) :: D) (*i is a smallvar*)
                        | inr el => ((inr (getarray el))::D) (*i is an array element*)
                                     (*here I add the entire array to the domain
                                      even though only one element has been assigned to*)
                        end
                      )
  end.

(*used to update NV memory with checkpoint*)
(*checks N first, then N'*)
Definition updatemaps (N: nvmem) (N': nvmem): nvmem :=
  match N, N' with
    NonVol m D, NonVol m' D' => NonVol
  (fun j =>
     match m j with
     error => m' j
     | x => x
     end
  )
  (D ++ D') (*inclusion of duplicates*)
  end.
Notation "m1 'U!' m2" := (updatemaps m1 m2) (at level 100).

Notation emptyNV := (NonVol (emptymap loc eqb_loc) nil).
Definition reset (V: vmem) := Vol (emptymap loc eqb_loc).

(*restricts memory map m to domain w*)
(*doesn't actually clean the unnecessary variables out of m*)
Definition restrict (N: nvmem) (w: warvars): nvmem :=
  match N with NonVol m D => NonVol
    (fun input => if (memberloc_wvs_b input w) then m input else error) w  end.

Notation "N '|!' w" := (restrict N w) 
  (at level 40, left associativity).

(*prop determining if every location in array a is in the domain of m*)
Definition indomain_nvm (N: nvmem) (w: warvar) :=
  memberwv_wv_b w (getdomain N).

Definition isdomain_nvm (N: nvmem) (w: warvars) :=
  eq_lists (getdomain N) w eq_warvar.

(********************************************)
Inductive cconf := (*continuous configuration*)
  ContinuousConf (triple: nvmem * vmem * command).

Notation context := (nvmem * vmem * command).

(*A coercion for cconf doesn't work because it's the same essential type as context.
 So, in practice, to avoid writing the constructor everywhere, I've been using contexts foralleverything, when conceptually a cconf would make more sense.
 It would be nice to just have one type for this.*)

Notation iconf := (context * nvmem * vmem * command).

Definition ro := loc * value. (*read observation*)
Definition readobs := list ro.

Notation NoObs := ([]: readobs).

Inductive obs := (*observation*)
  Obs (r: readobs)
| reboot
| checkpoint.
Coercion Obs : readobs >-> obs.

Notation obseq := (list obs). (*observation sequence*)

Open Scope list_scope.

(*helpers for observations and warvars*)

(*converts from list of read locations to list of
WAR variables
 *)
Fixpoint readobs_warvars (R: readobs) : warvars := 
  match R with
    nil => nil
| (r::rs) => match r with
              (location, _) => (*get the location r has recorded reading from*)
              (match location with
                inl x => (inl x)::(readobs_warvars rs) (*location is a smallvar*)
              | inr el => (inr (getarray el))::(readobs_warvars rs) (*location is an array element
                                                                   records entire array in warvars*)
              end)
           end
  end.

Fixpoint readobs_loc (R: readobs): (list loc) := 
  match R with
    nil => nil
| (r::rs) => match r with
             (location, _) => location :: (readobs_loc rs)
           end
  end.

(*relations between continuous and intermittent observations*)
(*Definition reduces (O1 O2: readobs) :=
  (prefix O1 O2*)
Notation "S <= T" := (prefix S T).

(*Where
O1 is a sequence of read observation lists,
where each continguous read observation list is separated from those adjacent to it by a reboot,
and O2 is a read observation list,
prefix_seq determines if each ro list in O1 is a valid
prefix of O2*)
Inductive prefix_seq: obseq -> readobs -> Prop :=
  RB_Base: forall(O: readobs), prefix_seq [Obs O] O
| RB_Ind: forall(O1 O2: readobs) (O1': obseq),
    O1 <= O2 -> prefix_seq O1' O2 -> prefix_seq ([Obs O1] ++ [reboot] ++ O1') O2.

(* Where
O1 is a sequence of ((read observation list sequences), where
each continguous read observation list is separated from those adjacent to it
by a reboot), where each sequence is separated from those adjacent to it by a checkpoint.
ie, each read observation list in a given read observation sequence
occurs within the same checkpointed region as all the other read observation lists in that sequence,
O2 is a read observation list,
prefix_frag determines if each ro list in O1 is a prefix of some FRAGMENT of O2
(where the fragments are separated by the positioning of the checkpoints in O1)
 *)
Inductive prefix_fragment: obseq -> readobs -> Prop :=
  CP_Base: forall(O1: obseq) (O2: readobs), prefix_seq O1 O2 -> prefix_fragment O1 O2
| CP_IND: forall(O1 O1': obseq) (O2 O2': readobs),
    prefix_seq O1 O2 -> prefix_fragment O1' O2' ->
   prefix_fragment (O1 ++ [checkpoint] ++ O1') (O2 ++ O2'). 

(***************************************************************)


(****************continuous operational semantics***********************)
(*evaluation relation for expressions*)

Inductive eeval: nvmem -> vmem -> exp -> readobs -> value -> Prop :=
  VAL: forall(N: nvmem) (V: vmem) (v: value),
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    eeval N V v NoObs v
| BINOP: forall(N: nvmem) (V: vmem)
          (e1: exp) (e2: exp)
          (r1: readobs) (r2: readobs)
          (v1: value) (v2: value) (bop: boptype),
    eeval N V e1 r1 v1 ->
    eeval N V e2 r2 v2 -> 
    (isvalidbop bop v1 v2) -> (*extra premise to check if v1, v2, bop v1 v2 valuable*)
    eeval N V (Bop bop e1 e2) (r1++ r2) (bopeval bop v1 v2)
| RD_VAR_NV: forall(N: nvmem) (mapV: vmem) (x: smallvar) (v: value),
    eq_value ((inl x) <-N) v ->
    isNV(x) -> (*extra premise to make sure x is correct type for NV memory*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    eeval N mapV (val x) [((inl x), v)] v
| RD_VAR_V: forall(N: nvmem) (mapV: mem) (x: smallvar) (v: value),
    eq_value (mapV (inl x)) v ->
    isV(x) -> (*extra premise to make sure x is correct type for V memory*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    eeval N (Vol mapV) (val x) [((inl x), v)] v
| RD_ARR: forall(N: nvmem) (V: vmem)
           (a: array)
           (index: exp)
           (rindex: readobs)
           (vindex: value)
           (element: el)
           (v: value),
    eeval N V (index) rindex vindex ->
    eq_value ((inr element) <-N) v ->
    (el_arrayind_eq element a vindex) -> (*extra premise to check that inr element
                                        is actually a[vindex] *)
(*well-typedness, valuability, inboundedness of vindex are checked in elpred*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    eeval N V (a[[index]]) (rindex++[((inr element), v)]) v
.
(*ask Arthur why this notation doesn't work *)

(*Reserved Notation "'{'N V'}=[' e ']=> <'r'>' v" (at level 40).
Inductive eevaltest: nvmem -> vmem -> exp -> obs -> value -> Prop :=
  VAL: forall(N: nvmem) (V: vmem) (v: value), 
    {N V} =[ v ]=> <reboot> v
  where "{N V}=[ e ]=> <r> v" := (eevaltest N V e r v).*)

(****************************************************************************)

(**********continuous execution semantics*************************)


(*evaluation relation for commands*)
Inductive cceval: context -> obseq -> context -> Prop :=
  NV_Assign: forall(x: smallvar) (N: nvmem) (V: vmem) (e: exp) (r: readobs) (v: value),
    eeval N V e r v ->
    isNV(x) -> (*checks x is correct type for NV memory*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    cceval (N, V, Ins (asgn_sv x e)) [Obs r]
           ((updateNV N (inl x) v), V, Ins skip)
| V_Assign: forall(x: smallvar) (N: nvmem) (mapV: mem) (e: exp) (r: readobs) (v: value),
    eeval N (Vol mapV) e r v ->
    isV(x) -> (*checks x is correct type for V memory*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    cceval (N, (Vol mapV), Ins (asgn_sv x e)) [Obs r] (N, (Vol ((inl x) |-> v ; mapV)), Ins skip)
| Assign_Arr: forall (N: nvmem) (V: vmem)
               (a: array)
               (ei: exp)
               (ri: readobs)
               (vi: value)
               (e: exp)
               (r: readobs)
               (v: value)
               (element: el),
    eeval N V ei ri vi ->
    eeval N V e r v ->
    (el_arrayind_eq element a vi) -> (*extra premise to check that inr element
                                        is actually a[vindex] *)
(*well-typedness, valuability, inboundedness of vindex are checked in elpred*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    cceval (N, V, Ins (asgn_arr a ei e)) [Obs (ri++r)]
           ((updateNV N (inr element) v), V, Ins skip)
    (*valuability and inboundedness of vindex are checked in sameindex*)
| CheckPoint: forall(N: nvmem)
               (V: vmem)
               (c: command)
               (w: warvars),
               cceval (N, V, ((incheckpoint w);; c)) [checkpoint]
               (N, V, c)
| Skip: forall(N: nvmem)
         (V: vmem)
         (c: command),
    cceval (N, V, (skip;;c)) [Obs NoObs] (N, V, c)
| Seq: forall (N N': nvmem)
         (V V': vmem)
         (l: instruction)
         (c: command)
         (o: obs),
    cceval (N, V, Ins l) [o] (N', V', Ins skip) ->
    cceval (N, V, (l;;c)) [o] (N', V', c)
| If_T: forall(N: nvmem)
         (V: vmem)
         (e: exp)
         (r: readobs)
         (c1 c2: command),
    eeval N V e r true -> 
    cceval (N, V, (TEST e THEN c1 ELSE c2)) [Obs r] (N, V, c1)
| If_F: forall(N: nvmem)
         (V: vmem)
         (e: exp)
         (r: readobs)
         (c1 c2: command),
    eeval N V e r false ->
    cceval (N, V, (TEST e THEN c1 ELSE c2)) [Obs r] (N, V, c2).

(************************************************************)

(**********intermittent execution semantics*************************)
(*evaluation relation for commands*)
Inductive iceval: iconf -> obseq -> iconf -> Prop :=
  CP_PowerFail: forall(k: context) (N: nvmem) (V: vmem) (c: command),
                 iceval (k, N, V, c)
                        nil
                        (k, N, (reset V), Ins inreboot)
 | CP_CheckPoint: forall(k: context) (N: nvmem) (V: vmem) (c: command) (w: warvars),
                 iceval (k, N, V, ((incheckpoint w);;c))
                        [checkpoint]
                        (((N |! w), V, c), N, V, c) 
 | CP_Reboot: forall(N N': nvmem) (*see below*) (*N is the checkpointed one*)
               (V V': vmem) 
               (c: command), 
     iceval ((N, V, c), N', V', Ins inreboot)
            [reboot]
            ((N, V, c), (N U! N'), V, c)
 | CP_NV_Assign: forall(k: context) (x: smallvar) (N: nvmem) (V: vmem) (e: exp) (r: readobs) (v: value),
    eeval N V e r v ->
    isNV(x) -> (*checks x is correct type for NV memory*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    iceval (k, N, V, Ins (asgn_sv x e))
           [Obs r]
           (k, (updateNV N (inl x) v), V, Ins skip)
| CP_V_Assign: forall(k: context) (x: smallvar) (N: nvmem) (mapV: mem) (e: exp) (r: readobs) (v: value),
    eeval N (Vol mapV) e r v ->
    isV(x) -> (*checks x is correct type for V memory*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    iceval (k, N, (Vol mapV), Ins (asgn_sv x e))
           [Obs r]
           (k, N, (Vol ((inl x) |-> v ; mapV)), Ins skip)
| CP_Assign_Arr: forall (k: context) (N: nvmem) (V: vmem)
               (a: array)
               (ei: exp)
               (ri: readobs)
               (vi: value)
               (e: exp)
               (r: readobs)
               (v: value)
               (element: el),
    eeval N V ei ri vi ->
    eeval N V e r v ->
    (el_arrayind_eq element a vi) -> (*extra premise to check that inr element
                                        is actually a[vindex] *)
(*well-typedness, valuability, inboundedness of vindex are checked in elpred*)
    (isvaluable v) -> (*extra premise to check if v is valuable*)
    iceval (k, N, V, Ins (asgn_arr a ei e))
           [Obs (ri++r)]
           (k, (updateNV N (inr element) v), V, Ins skip)
| CP_Skip: forall(k: context) (N: nvmem)
         (V: vmem)
         (c: command),
    iceval (k, N, V, (skip;;c)) [Obs NoObs] (k, N, V, c)
|CP_Seq: forall (k: context)
         (N: nvmem) (N': nvmem)
         (V: vmem) (V': vmem)
         (l: instruction)
         (c: command)
         (o: obs),
    iceval (k, N, V, Ins l) [o] (k, N', V', Ins skip) ->
    iceval (k, N, V, (l;;c)) [o] (k, N', V', c)
|CP_If_T: forall(k: context) (N: nvmem) (V: vmem)
         (e: exp)
         (r: readobs)
         (c1 c2: command),
    eeval N V e r true -> 
    iceval (k, N, V, (TEST e THEN c1 ELSE c2)) [Obs r] (k, N, V, c1)
|CP_If_F: forall(k: context) (N: nvmem) (V: vmem)
         (e: exp)
         (r: readobs)
         (c1 c2: command),
    eeval N V e r false ->
    iceval (k, N, V, (TEST e THEN c1 ELSE c2)) [Obs r] (k, N, V, c2).
(*CP_Reboot: I took out the equals premise and instead built it
into the types because I didn't want to define a context equality function*)

(********************************************)
(*traces*)

(*trace helpers*)


Definition el_arrayexp_eq (e: el) (a: array) (eindex: exp) (N: nvmem) (V: vmem) := (*transitions from el type to a[exp] representation*)
  (samearray e a) /\
  exists(r: readobs) (vindex: value), eeval N V eindex r vindex /\
                                 (eq_value (getindexel e) vindex).


(*do I keep track of volatile writes as well...I don't think so
 cuz the writes don't last and they all have to be checkpointed anyways*)
(*actually there's no reason for us to be checkpointing volatiles that are
 written to before they're ever read from along any path*)
(*at first inspection it doesn't seem like it would be all that hard to keep track of this
 since we're already doing MFstWt for novolatiles*)

(*using context instead of cconf cuz they're exactly the same
 but cconf has an annoying constructor*)

(*The trace type contains
1. a starting configuration and ending configuration
2. a list of warvars which have been written to
3. a list of warvars which have been read from
4. a list of warvars which have been written to before they have been read from
 *)


(* Concern:
The trace relation below does everything the cceval relation does and more because it
steps everything to completion. I do lose the ability to step from l;;c to c
without stepping c, however.
 Based on cursory inspection of the proofs, don't ever need this one step evaluation.
If further inspection of the proofs verifies this, I'll remove the cceval relation.
 *)

(*written, read, written before reading*)
Notation the_write_stuff := ((list loc) * (list loc) * (list loc)).

(*start -> end -> written -> read -> written before reading -> obseq*)
Inductive trace_c: context -> context -> the_write_stuff -> obseq -> Prop :=
(*what if x is read in e...fix this!*)
  CTrace_Assign_nv: forall(x: smallvar) (N N': nvmem) (V V': vmem) (e: exp) (r: readobs),
    isNV(x) -> (*checks x is in NV memory*)
    cceval (N, V, Ins (asgn_sv x e)) [Obs r] (N', V', Ins skip) ->
    trace_c (N, V, Ins (asgn_sv x e))
            (N', V', Ins skip)
            [inl x]  (readobs_loc r) (remove in_loc_b (readobs_loc r) [inl x]) [Obs r]
| CTrace_Assign_v: forall(x: smallvar) (N N': nvmem) (V V': vmem) (e: exp) (r: readobs),
    isV(x) -> (*checks x is in volatile memory*)
    cceval (N, V, Ins (asgn_sv x e)) [Obs r] (N', V', Ins skip) ->
    trace_c (N, V, Ins (asgn_sv x e)) (N', V', Ins skip)
            nil  (readobs_loc r) nil [Obs r]
| CTrace_Assign_Arr: forall (N N': nvmem) (V V': vmem)
               (a: array)
               (ei: exp)
               (ri: readobs)
               (e: exp)
               (r: readobs)
               (element: el),
    (el_arrayexp_eq element a ei N V) -> (*extra premise to check that inr element
                                        is actually a[ei] *)
    cceval (N, V, Ins (asgn_arr a ei e)) [Obs (ri++r)] (N', V', Ins skip) ->
    trace_c (N, V, Ins (asgn_arr a ei e)) (N', V', Ins skip)
            [inr element] (readobs_loc (ri ++ r)) [inr element] [Obs (ri ++ r)]
| CTrace_CheckPoint: forall(N: nvmem)
               (V: vmem)
               (c: command)
               (w: warvars),
    trace_c (N, V, (incheckpoint w);; c) (N, V, c)
            nil nil nil [checkpoint]
| CTrace_Skip: forall(N: nvmem)
         (V: vmem)
         (c: command),
    trace_c (N, V, skip;; c) (N, V, c)
            nil nil nil [Obs NoObs]
| CTrace_Seq: forall (N N' N'': nvmem)
         (V V' V'': vmem)
         (WT1 RD1 FstWt1 WT2 RD2 FstWt2: list loc)
         (O1 O2: obseq)
         (l: instruction)
         (c: command)
         (r: readobs),
    trace_c (N, V, Ins l) (N', V', Ins skip) WT1 RD1 FstWt1 O1 ->
    trace_c (N', V', c) (N'', V'', Ins skip) WT2 RD2 FstWt2 O2->
    trace_c (N, V, l;;c) (N'', V'', Ins skip) (WT1 ++ WT2) (RD1 ++ RD2) (FstWt1 ++ (remove in_loc_b RD1 FstWt2))
            (O1 ++ O2)
| CTrace_If_T: forall(N N': nvmem)
                (V V': vmem)
                (WT RD FstWt: list loc)
                (e: exp)
                (r: readobs)
                (c1 c2: command)
                (O1: obseq)
  ,
    cceval (N, V, (TEST e THEN c1 ELSE c2)) [Obs r] (N, V, c1) ->
    trace_c (N, V, c1) (N', V', Ins skip) WT RD FstWt O1 ->
    trace_c (N, V, TEST e THEN c1 ELSE c2) (N', V', Ins skip) WT ((readobs_loc r) ++ RD) FstWt ((Obs r)::O1) 
| CTrace_If_F: forall(N N': nvmem)
                (V V': vmem)
                (WT RD FstWt: list loc)
                (e: exp)
                (r: readobs)
                (c1 c2: command)
                (O2: obseq),
    cceval (N, V, (TEST e THEN c1 ELSE c2)) [Obs r] (N, V, c2) ->
    trace_c (N, V, c2) (N', V', Ins skip) WT RD FstWt O2->
    trace_c (N, V, TEST e THEN c1 ELSE c2) (N', V', Ins skip) WT ((readobs_loc r) ++ RD) FstWt ((Obs r)::O2).

(*trace_i*)
(*start -> end -> written -> read -> written before reading -> obseq*)
(*chose to include context in start and end values to ensure consistency with iceval
 in reboot case*)
(*Inductive trace_i: iconf -> iconf -> (list loc) -> (list loc) -> (list loc) -> obseq -> Prop :=
  iTrace_PowerFail: forall(k: context) (N: nvmem) (V: vmem) (c: command),
    iceval k N V c
    trace_i (k, N, V, c) (k, N, (reset V), Ins inreboot) nil nil nil nil 
 | iTrace_CheckPoint: forall(k: context) (N: nvmem) (V: vmem) (c: command) (w: warvars),
     trace_i (k, N, V, (incheckpoint w);;c) (((N |! w), V, c), N, V, c)
             nil nil nil [checkpoint].
 | CP_Reboot: forall(N: nvmem) (N': nvmem)(*see below*) (*N is the checkpointed one*)
               (V: vmem) (V': vmem)
               (c: command), 
     trace_i ((N, V, c), N', V', Ins inreboot) ((N, V, c), N U! )
     iceval (N, V, c) N' V' inreboot
            [reboot]
            (N, V, c) (N U! N') V c
  CTrace_Assign_nv: forall(x: smallvar) (N N': nvmem) (V V': vmem) (e: exp) (r: readobs),
    isNV(x) -> (*checks x is in NV memory*)
    cceval N V (asgn_sv x e) [Obs r] N' V' skip ->
    trace_c (N, V, Ins (asgn_sv x e)) (N', V', Ins skip)
            [inl x]  (readobs_loc r) [inl x] [Obs r]
| CTrace_Assign_v: forall(x: smallvar) (N N': nvmem) (V V': vmem) (e: exp) (r: readobs),
    isV(x) -> (*checks x is in volatile memory*)
    cceval N V (asgn_sv x e) [Obs r] N' V' skip ->
    trace_c (N, V, Ins (asgn_sv x e)) (N', V', Ins skip)
            nil  (readobs_loc r) nil [Obs r]
| CTrace_Assign_Arr: forall (N N': nvmem) (V V': vmem)
               (a: array)
               (ei: exp)
               (ri: readobs)
               (e: exp)
               (r: readobs)
               (element: el),
    (el_arrayexp_eq element a ei N V) -> (*extra premise to check that inr element
                                        is actually a[ei] *)
    cceval N V (asgn_arr a ei e) [Obs (ri++r)] N' V' skip ->
    trace_c (N, V, Ins (asgn_arr a ei e)) (N', V', Ins skip)
            [inr element] (readobs_loc (ri ++ r)) [inr element] [Obs (ri ++ r)]
| CTrace_CheckPoint: forall(N: nvmem)
               (V: vmem)
               (c: command)
               (w: warvars),
    trace_c (N, V, (incheckpoint w);; c) (N, V, c)
            nil nil nil [checkpoint]
| CTrace_Skip: forall(N: nvmem)
         (V: vmem)
         (c: command),
    trace_c (N, V, skip;; c) (N, V, c)
            nil nil nil [Obs NoObs]
| CTrace_Seq: forall (N N' N'': nvmem)
         (V V' V'': vmem)
         (WT1 RD1 FstWt1 WT2 RD2 FstWt2: list loc)
         (O1 O2: obseq)
         (l: instruction)
         (c: command)
         (r: readobs),
    trace_c (N, V, Ins l) (N', V', Ins skip) WT1 RD1 FstWt1 O1 ->
    trace_c (N', V', c) (N'', V'', Ins skip) WT2 RD2 FstWt2 O2->
    trace_c (N, V, l;;c) (N'', V'', Ins skip) (WT1 ++ WT2) (RD1 ++ RD2) (FstWt1 ++ (remove in_loc_b RD1 FstWt2))
            (O1 ++ O2)
| CTrace_If_T: forall(N N': nvmem)
                (V V': vmem)
                (WT RD FstWt: list loc)
                (e: exp)
                (r: readobs)
                (c1 c2: command)
                (O1: obseq)
  ,
    cceval N V (TEST e THEN c1 ELSE c2) [Obs r] N V c1 ->
    trace_c (N, V, c1) (N', V', Ins skip) WT RD FstWt O1 ->
    trace_c (N, V, TEST e THEN c1 ELSE c2) (N', V', Ins skip) WT ((readobs_loc r) ++ RD) FstWt ((Obs r)::O1) 
| CTrace_If_F: forall(N N': nvmem)
                (V V': vmem)
                (WT RD FstWt: list loc)
                (e: exp)
                (r: readobs)
                (c1 c2: command)
                (O2: obseq),
    cceval N V (TEST e THEN c1 ELSE c2) [Obs r] N V c2 ->
    trace_c (N, V, c2) (N', V', Ins skip) WT RD FstWt O2->
    trace_c (N, V, TEST e THEN c1 ELSE c2) (N', V', Ins skip) WT ((readobs_loc r) ++ RD) FstWt ((Obs r)::O2).
(*last one necessary to compute nearest checkpoint*)

(*relations between continuous and intermittent memory*)
Inductive same_ex_point: forall(N1 N2 N: nvmem) (V V': vmem) (c c': command),
    same_program: forall(T1 T2: trace_i),
      (getdomain N1) = (getdomain N2) -> (*putting equals for now, if this bites me later on I can define an                                        extensional equality relation with eqtype*)
      (get_start T1) = (N, V, c) ->
      (get_end T1) = (N1, V', c') ->
      (get_start T2) = (N1, V', c') ->
      get_command (get_end T2) = inscheckpoint ->
      no_checkpts T1 ->
      forall(l: loc), not((N1 l) = (N2 loc)) -> ((In l (Wt T1)) /\ (In l (FstWt (T1 @ T2))) /\ not (In l (Wt T1))).
                                          (*same here with equality*)
*)
Close Scope list_scope.
Close Scope type_scope.
