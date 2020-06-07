Set Warnings "-notation-overridden,-parsing".
From Coq Require Import Bool.Bool Init.Nat Arith.Arith Arith.EqNat
     Init.Datatypes Lists.List Strings.String Program Init.Logic.
Require Export Coq.Strings.String.
From TLC Require Import LibTactics LibLogic.
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype.
From Semantics Require Import algorithms.


Open Scope type_scope.


Open Scope list_scope.
(************* program traces*****************)

(*trace helpers*)
(*first three get on my nerves; coq insists that whenever I want to access elements of the_write_stuff
I need to pass in all elements as separate arguments

 Without these helpers in CTrace_App,
when I try to use the CTrace_App constructor inside another function,
it'll complain that I'm passing in a trace defined with
 the_write_stuff when I should actually be passing in
a trace defined with a triple...
 *)

(*Michael look here*)
(*I needed a type for tracking the variables written to during a program's execution*)
(*guess what I called it*)
Definition getwt (W: the_write_stuff) := match W with (out, _, _ )=> out end.

Definition getrd (W: the_write_stuff) := match W with (_, out , _ )=> out end.

Definition getfstwt (W: the_write_stuff) := match W with (_, _, out )=> out end.

Notation emptysets := ((nil : list loc), (nil: list loc), (nil: list loc)).

(*Michael look here*)
(*...do you get it....append the write sets....append the RIGHT sets....... :3*)
Definition append_write (W1 W2: the_write_stuff) :=
((getwt W1) ++ (getwt W2), (getrd W1) ++ (getrd W2), (getfstwt W1) ++ (remove in_loc_b (getrd W1) (getfstwt W2))).

Definition combine_write (WL: list the_write_stuff) :=
fold_right append_write emptysets WL.
Notation step :=(context * obseq * context).

 Fixpoint last {A: Type} (l:list A) :=
  match l with
    | [] => None
    | [a] => Some a
    | a :: l => last l
  end.

 Check classicT.

 (*Michael look here*)
 Program Definition gethead (L: list context) (H: L <> []):=
   match L with
     [] => !
    | out::xs => out end.
 (*trying with pointers*)
 Inductive step_term : (list context) -> (list obseq) -> (list the_write_stuff) -> Prop :=
   Step_Single : forall{C1: context} {N2: nvmem} {V2: vmem} {O: obseq} {W: the_write_stuff},
     cceval_w C1 O (N2, V2, (Ins skip)) W -> step_term (C1::[(N2, V2, (Ins skip))]) [O] [W]
 | Step_Many: forall{C1 C2: context} {O1: obseq} {W1: the_write_stuff} (*makes program bigger*)
               {Crest: (list context)} {Orest: (list obseq)} {Wrest: (list the_write_stuff)}    (H: Crest <> nil), 
     step_term Crest Orest Wrest ->
     cceval_w C1 O1 (gethead Crest H) W1 ->
     step_term (C1::Crest) (O1:: Orest) (W1:: Wrest).

 Inductive trace_c (CL: list context) (WL: list the_write_stuff) (OL: list obseq): nat -> nat -> Prop :=
   Trace_C: forall
             (s e: nat)
             (H1: s < (List.length CL))
             (H2: e < (List.length CL)),
             step_term CL OL WL ->
             trace_c CL WL OL s e.
Theorem trace_append : forall {CL: list context} {WL: list the_write_stuff} {OL: list obseq} {s1 mid e2: nat}
                                          (T1: trace_c CL WL OL s1 mid) (T2: trace_c CL WL OL mid e2),
     trace_c CL WL OL s1 e2.
  intros. inversion T1. inversion T2. subst.
  apply (Trace_C CL WL OL s1 e2 H1 H5 H6). Qed.


 

 (*contexts at end is ending context*)
 (*can take anything out, ie, step the front, and the end stays the same*)
 (*want it to be so that combining the stuff is just appending
  but first write doesn't work like that*)
 (*why is it that I can't combine the write data in real time again?*)
 (*here you're going up AND down...won't work
 Inductive trace_c: (list step) -> context -> (list the_write_stuff) -> Type :=
  CTrace_Empty: forall(C: context), trace_c nil C nil
| CTrace_single: forall {C1 C2: context} {O: obseq} {W: the_write_stuff},
    cceval_w C1 O C2 W ->
    trace_c [(C1, O, C2)] C2 [W]
| CTrace_Step1: forall{C1 Cmid C3: context} {Omid: obseq} {W3: the_write_stuff} {L: list step} {WT: list the_write_stuff}
  {H: L <> []},
    trace_c L C3 WT ->
    L <> [] -> (*if you want to do a single step use the single constructor; I haven't got time for an infinite loop*)
    trace_c (tl L) C3 (tl WT) (*steps the front of the trace*)
| CTrace_Step2: forall{Cmid C3: context} {O3: obseq} {W3: the_write_stuff} {L: list step} {WT: list the_write_stuff},
    trace_c L Cmid WT ->
    L <> [] ->
    cceval_w Cmid O3 C3 W3 ->
    trace_c (L ++ [(Cmid, O3, C3)]) C3 (WT ++ [W3]). (*steps the back of the trace*)*)
(*maybe have append instead of Step2 as a constructor*)
 (*Theorem trace_step: forall{L: list step} {Cend: context} {WL: list the_write_stuff},
                      trace_c L Cend WL ->
                      trace_c (tl L) Cend (tl WL).
   intros L. induction L; intros Cend WL T.
   + inversion T; subst.
     - simpl. constructor.
     - apply app_eq_nil in H. destruct H. discriminate H2.
       + inversion T; subst.
     - simpl. constructor.
     - simpl.  rewrite H in T.*)



(*intermittent traces*)
 (*the same as trace_c bar types as differences between
  intermittent and continuous execution have been implemented in evals*)
(*Inductive trace_i : iconf -> iconf -> obseq -> the_write_stuff -> Prop :=
iTrace_Empty: forall{C: iconf},
                 trace_i C C nil (nil, nil, nil)
|iTrace_Single: forall{C1 C2: iconf} {O: obseq} {W: the_write_stuff},
                  iceval_w C1 O C2 W -> (*command in C2 is skip by def single_com, iceval_w*)
                  trace_i C1 C2 O W
| iTrace_App: forall{C1 C2 Cmid: iconf} {O1 O2: obseq}
         {W1 W2: the_write_stuff},
    trace_i C1 Cmid O1 W1 -> (*steps first section*)
    trace_i Cmid C2 O2 W2 -> (*steps rest of program*)
    trace_i C1 C2 (O1 ++ O2) (append_write W1 W2).*)

(*michael look here
Definition multi_step_c (C1 C2: context) (O: obseq) :=
    exists W: the_write_stuff, inhabited (trace_c C1 C2 O W). *)

(*more trace helpers*)

(*Fixpoint acc_wts (L: list step) :=
  match L with
    [] => emptysets
  |(((_, _, _), W1):: xs) => append_write W1 (acc_wts xs) end.*)

Fixpoint acc_obs (L: list obseq) :=
  match L with
    [] => []
  |(obs:: xs) => obs ++ (acc_obs xs) end.

(*(nth_error CL e) *)

Definition Wt {CL: list context} {WL: list the_write_stuff} {OL: list obseq} {s e: nat} (T: trace_c CL WL OL s e) :=
getwt (combine_write (firstn (e- s + 1) (skipn s WL))).


Definition FstWt {CL: list context} {WL: list the_write_stuff} {OL: list obseq}{s e: nat} (T: trace_c CL WL OL s e) :=
getfstwt (combine_write (firstn (e- s + 1) (skipn s WL))).


Definition getobs {CL: list context} {WL: list the_write_stuff} {OL: list obseq}{s e: nat}
           (T: trace_c CL WL OL s e) :=
  acc_obs ( (firstn (e- s + 1) (skipn s OL))).

Definition getstart {CL: list context} {WL: list the_write_stuff} {OL: list obseq} {s e: nat}
           (T: trace_c CL WL OL s e) :=
  nth_error CL s.

Definition getend {CL: list context} {WL: list the_write_stuff} {OL: list obseq} {s e: nat}
           (T: trace_c CL WL OL s e) :=
  nth_error CL e.
(**********************************************************************************)

Definition multi_step_c (C1 C2: context) (O: obseq)  :=
  exists {CL: list context} {WL: list the_write_stuff} {OL: list obseq}
    {s e: nat} (T: trace_c CL WL OL s e), (getobs T) = O /\ (getstart T) = (Some C1) /\ (getend T) = (Some C2).

(*Definition multi_step_i (C1 C2: iconf) (O: obseq) :=
    exists W: the_write_stuff, trace_i C1 C2 O W.*)

(*relations between continuous and intermittent memory*)


(*Definition 4*)
(*concern: not yet clear to me why we need the vmem parameter; pending further inspection of
 proofs*)
(*concern: liberal use of intensional equality with nvmem*)
(*N0, V0 is starting state for both executions
 N1, V1 and Ncomp are middle states of intermittent, continuous respectively
 V1 isn't used anywhere it's just to fill out the type
 N2, V2 is final state for intermittent, once again solely to fill out the type*)

(*ask Arthur how to not do this*)
Lemma refl_context : forall (C1: context), C1 = C1.
intros. reflexivity. Qed. 

(*what about a relation for when there's not a checkpoint left?*)
Inductive same_pt: nvmem -> vmem -> command -> command -> nvmem -> nvmem -> Prop:=
same_mem: forall {N0 N1 N2 Ncomp: nvmem}
                  {V0 V1 V2: vmem}
                  {c0 c1 c2: command}
                  {w: warvars}
                  {L: list context}
                  {O: list obseq}
                  {W: list the_write_stuff}
                  {s1 mid e2: nat}
                  (T1: trace_c L W O s1 mid)
                  (T2: trace_c L W O mid e2),
                  (getstart T1 = Some (N0, V0, c0)) ->
                  (getend T1 = Some (N1, V1, c1)) ->
                  (getend T2 = Some (N2, V2, (incheckpoint w);; c2)) -> 
                  (getdomain N1) = (getdomain Ncomp)
                  -> not (In checkpoint (getobs T1))
                  -> not (In checkpoint (getobs T2)) (*checks checkpoint T2 ends on is nearest checkpoint*)
                 -> (forall(l: loc),
                      not((getmap N1) l = (getmap Ncomp) l)
                      -> ((In l (Wt T2)) /\ (In l (FstWt (trace_append T1 T2)
                                                          ))) /\ not (In l (Wt T1)))
                  -> same_pt N0 V0 c0 c1 N1 Ncomp.
(*Definition 5*)
(*N0, V0 is starting state for both executions
 N1 V1 is middle state for intermittent
N is state of checkpoint at N1
 V1 isn't used anywhere it's just to fill out the type
 N2, V2 is final state for intermittent, once again solely to fill out the type*)
Inductive current_init_pt: nvmem -> vmem -> command -> nvmem -> nvmem -> Prop:=
valid_mem: forall {N N0 N1 N2: nvmem}
                  {V0 V1 V2: vmem}
                  {c c1: command}
                  {w: warvars}
                  {CL: list context}
                  {O: list obseq}
                  {W: list the_write_stuff}
                  {s e: nat}
                  (T: trace_c CL W O s e),
    (getstart T) = Some (N1, V1, c) ->
    (getend T) = Some (N2, V2, (incheckpoint w) ;; c1 ) ->
                  (getdomain N1) = (getdomain N0) 
                  -> not (In checkpoint (getobs T)) (*checks checkpoint T ends on is nearest checkpoint*)
                 -> (forall(l: loc),
                      not((getmap N1) l = (getmap N0) l)
                      -> (In l (FstWt T)) \/ (In (loc_warvar l) (getdomain N)))
                 -> current_init_pt N V1 c N1 N0.

(*Definition 6*)
(*concern: Typo in paper, N0, V0 is left out of invocation of Def 4*)
(*(N0, V0, c0) is checkpoint state at time c1
N1 V c is intermittent state
N2 V c is continuous state starting from same state as checkpoint
concern: using context instead of cconf
 *)
(*took out equality premises and built them into the types*)
Check same_pt.
Inductive same_config: iconf -> context -> Prop :=
  SameConfig: forall(N0 N1 N2: nvmem)
                (V0 V: vmem)
                (c0 c: command),
                same_pt N0 V0 c0 c N1 N2 -> (*nvms are extensionally the same by same_pt
                                          vms and cs are intensionally the same by types*)
                same_config ((N0, V0, c0), N1, V, c) (N2, V, c).

Close Scope list_scope.
Close Scope type_scope.
