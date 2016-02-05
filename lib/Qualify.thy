(*
  Post-hoc qualification of global constants, facts and types using name space aliasing.
  Can be used to add mandatory qualification to otherwise non-localised commands (i.e. "record",
  "instantiation").

  This is a hack that should be replaced with proper "context begin ... end" blocks when
  commands are appropriately localized.
*)

theory Qualify
imports Main
keywords "qualify" :: thy_decl and "end_qualify" :: thy_decl
begin
ML \<open>

structure Data = Theory_Data
  (
    type T = (theory * string) option * 
             ((string * 
              ((binding Symtab.table) * (* facts *)
               (binding Symtab.table) * (* consts *)
               (binding Symtab.table) (* types *))) list);
    val empty = (NONE, []);
    val extend = I;
    fun merge (((_, tabs), (_, tabs')) : T * T) = 
      (NONE, AList.join (op =) 
      (fn _ => fn ((facts, consts, types), (facts', consts', types')) =>
        (Symtab.merge (op =) (facts, facts'), 
         Symtab.merge (op =) (consts, consts'),
         Symtab.merge (op =) (types, types')))
      (tabs, tabs'));
  );

fun get_qualify thy = fst (Data.get thy);

fun get_tabs_of thy str = 
  the_default (Symtab.empty, Symtab.empty, Symtab.empty) (AList.lookup (op =) (snd (Data.get thy)) str);

fun get_facts_of thy str = #1 (get_tabs_of thy str);

fun get_consts_of thy str = #2 (get_tabs_of thy str);

fun get_types_of thy str = #3 (get_tabs_of thy str);

fun map_tabs_of str f thy = 
  Data.map (apsnd (AList.map_default (op =) (str, (Symtab.empty, Symtab.empty, Symtab.empty)) f)) thy;

fun map_facts_of str f thy = map_tabs_of str (@{apply 3(1)} f) thy;

fun map_consts_of str f thy = map_tabs_of str (@{apply 3(2)} f) thy;

fun map_types_of str f thy = map_tabs_of str (@{apply 3(3)} f) thy;

fun make_bind nm = 
  let
    val base = Long_Name.explode nm |> tl |> rev |> tl |> rev;
  in fold (Binding.qualify false) base (Binding.make (Long_Name.base_name nm, Position.none)) end;

fun get_new_facts old_thy facts = 
  Facts.dest_static false [Global_Theory.facts_of old_thy] facts
  |> map (fn (nm, _) => `make_bind nm);

fun get_new_consts old_thy consts =
  let
    val new_consts = #constants (Consts.dest consts)
    |> map fst;
    
    val consts = 
      filter (fn nm => not (can (Consts.the_const (Sign.consts_of old_thy)) nm) andalso
                       can (Consts.the_const consts) nm) new_consts
      |> map (fn nm => `make_bind nm);

  in consts end;

fun get_new_types old_thy types =
  let
    val new_types = #types (Type.rep_tsig types);

    val old_types = #types (Type.rep_tsig (Sign.tsig_of old_thy));
   
    val types = (new_types
      |> Name_Space.fold_table (fn (nm, _) => 
           not (Name_Space.defined old_types nm) ? cons nm)) []
      |> map (fn nm => `make_bind nm);
  in types end;

fun add_qualified qual nm =
  let
    val nm' = Long_Name.explode nm |> rev |> tl |> hd;
  in if qual = nm' then cons nm else I end
  handle List.Empty => I

fun make_bind_local nm = 
  let
    val base = Long_Name.explode nm |> tl |> tl |> rev |> tl |> rev;
  in fold (Binding.qualify true) base (Binding.make (Long_Name.base_name nm, Position.none)) end;

fun set_global_qualify str thy = 
  let
    val _ = Locale.check thy (str, Position.none)
    val _ = case get_qualify thy of SOME _ => error "Already in a qualify block!" | NONE => ();

    val facts = 
      Facts.fold_static (fn (nm, _) => add_qualified str nm) (Global_Theory.facts_of thy) []
      |> map (`make_bind_local)

    val consts = fold (fn (nm, _) => add_qualified str nm) (#constants (Consts.dest (Sign.consts_of thy))) []
      |> map (`make_bind_local)

    val types = 
      Name_Space.fold_table (fn (nm, _) => add_qualified str nm) (#types (Type.rep_tsig (Sign.tsig_of thy))) []
      |> map (`make_bind_local)


    val thy' = thy
     |> map_facts_of str (fold (fn (b, nm) => (Symtab.update (nm, b))) facts)
     |> map_consts_of str (fold (fn (b, nm) => (Symtab.update (nm, b))) consts)
     |> map_types_of str (fold (fn (b, nm) => (Symtab.update (nm, b))) types)

    val thy'' = thy'
    |> Data.map (apfst (K (SOME (thy,str))))
    |> fold (fn (nm, b) => Global_Theory.alias_fact b nm) (Symtab.dest (get_facts_of thy' str))
    |> fold (fn (nm, b) => Sign.const_alias b nm) (Symtab.dest (get_consts_of thy' str))
    |> fold (fn (nm, b) => Sign.type_alias b nm) (Symtab.dest (get_types_of thy' str))

  in thy'' end

val _ =
  Outer_Syntax.command @{command_keyword qualify} "begin global qualification"
    (Parse.name >> 
      (fn str => Toplevel.theory (set_global_qualify str)));

fun syntax_alias global_alias local_alias b name =
  Local_Theory.declaration {syntax = true, pervasive = true} (fn phi =>
    let val b' = Morphism.binding phi b
    in Context.mapping (global_alias b' name) (local_alias b' name) end);

val fact_alias = syntax_alias Global_Theory.alias_fact Proof_Context.fact_alias;
val const_alias = syntax_alias Sign.const_alias Proof_Context.const_alias;
val type_alias = syntax_alias Sign.type_alias Proof_Context.type_alias;



fun end_global_qualify thy =
  let
    val (old_thy, nm) = 
      case get_qualify thy of
        SOME x => x 
      | NONE => error "Not in a global qualify"

    val facts = get_new_facts old_thy (Global_Theory.facts_of thy);

    val consts = get_new_consts old_thy (Sign.consts_of thy);

    val types = get_new_types old_thy (Sign.tsig_of thy);


    val thy' = thy
     |> map_facts_of nm (fold (fn (b, nm) => (Symtab.update (nm, b))) facts)
     |> map_consts_of nm (fold (fn (b, nm) => (Symtab.update (nm, b))) consts)
     |> map_types_of nm (fold (fn (b, nm) => (Symtab.update (nm, b))) types)
     |> (fn thy => fold (Global_Theory.hide_fact false o fst) (Symtab.dest (get_facts_of thy nm)) thy)
     |> (fn thy => fold (Sign.hide_const false o fst) (Symtab.dest (get_consts_of thy nm)) thy)
     |> (fn thy => fold (Sign.hide_type false o fst) (Symtab.dest (get_types_of thy nm)) thy)
     |> Data.map (apfst (K NONE))

    val lthy = Named_Target.begin (nm, Position.none) thy';

    val lthy' = lthy
      |> fold (uncurry fact_alias o swap) (Symtab.dest (get_facts_of thy' nm))
      |> fold (uncurry const_alias o swap) (Symtab.dest (get_consts_of thy' nm))
      |> fold (uncurry type_alias o swap) (Symtab.dest (get_types_of thy' nm));

  in Local_Theory.exit_global lthy' end

val _ =
  Outer_Syntax.command @{command_keyword end_qualify} "end global qualification"
    (Scan.succeed
      (Toplevel.theory end_global_qualify));


\<close>

setup \<open>Theory.at_end 
  (fn thy => case get_qualify thy of SOME (_, nm) => 
    SOME (end_global_qualify thy) | NONE => NONE)\<close>

end