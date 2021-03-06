
open Prohlatype

let j =
  Post_analysis.of_json_file
    "FILL ME/res/2017_12_12_full_class1/004.json"

let j_bl =
  Post_analysis.reads_by_loci j
let j_bl_A =
  assoc_exn Nomenclature.A j_bl
let j_bl_A1, j_bl_A2 =
  List.partition ~f:(fun (a, _, _) -> a = "A*24:53") j_bl_A

let specific_reads =
  List.map j_bl_A1 ~f:(fun (_, rn, _) -> rn)

let smap =
  List.map j_bl_A1 ~f:(fun (_, rn, r) -> rn, r)
  |> string_map_of_assoc

let a1 = "A*24:02:01:01"
let a2 = "A*68:01:02:01"

let ai = Alleles.Input.merge ~distance:Distances.WeightedPerSegment "../foreign/IMGTHLA/alignments/A"

let file1 = "FILL MEfastqs/PGV_004_1.fastq"
let file2 = "FILL MEfastqs/PGV_004_2.fastq"

module Pd = ParPHMM_drivers
module Pa = Post_analysis
module Ml = Pd.Multiple_loci

let char_of_two_ls l1 l2 =
  if l1 = l2 then      'E'
  else if l1 < l2 then 'L'
  else (* l1 > l2 *)   'G'

let pt = ParPHMM.construct ai |> unwrap
let prealigned_transition_model = true
let read_length = 125

let fpt1 =
  ParPHMM.setup_single_allele_forward_pass ~prealigned_transition_model
    read_length a1 pt
let alleles1 = [| a1 |]

let fpt2 =
  ParPHMM.setup_single_allele_forward_pass ~prealigned_transition_model
    read_length a2 pt

let alleles2 = [| a2 |]

open Versus_common

let paired readname rs1 re1 rs2 re2 =
  let module Aap = Pd.Alleles_and_positions in
  match StringMap.find readname smap with
  | Pa.Pr (Ml.FirstFiltered _) ->
      eprintf "%s was FirstFiltered ?" readname
  | Pa.Pr (Ml.FirstOrientedSecond { Ml.first_o; _}) ->
      let l11 = callhd alleles1 fpt1 rs1 re1 first_o in
      let l12 = callhd alleles1 fpt1 rs2 re2 (not first_o) in
      let l21 = callhd alleles2 fpt2 rs1 re1 first_o in
      let l22 = callhd alleles2 fpt2 rs2 re2 (not first_o) in
      printf "%s\tp 1\t%c\t%s\t%d\t%s\t%d\n%!"
        readname (char_of_two_ls l11.Aap.llhd l21.Aap.llhd)
          (ParPHMM.Lp.to_string l11.Aap.llhd)
          l11.Aap.position
          (ParPHMM.Lp.to_string l21.Aap.llhd)
          l21.Aap.position;
      printf "%s\tp 2\t%c\t%s\t%d\t%s\t%d\n%!"
        readname (char_of_two_ls l12.Aap.llhd l22.Aap.llhd)
          (ParPHMM.Lp.to_string l12.Aap.llhd)
          l12.Aap.position
          (ParPHMM.Lp.to_string l22.Aap.llhd)
          l22.Aap.position
  | Pa.Soi _ ->
      eprintf "%s supposed to be paired!" readname

let single rp readname rs re =
  let open ParPHMM in
  let module Aap = Pd.Alleles_and_positions in
  let take_regular r c = Aap.descending_cmp r c <= 0 in
  let mlo fp = Pd.Orientation.most_likely_between ~take_regular fp in
  match StringMap.find readname smap with
  | Pa.Soi (Ml.SingleRead or_) ->
      begin match mlo or_ with
      | Pass_result.Filtered _ -> eprintf "%s filtered!" readname
      | Pass_result.Completed (rc, _) ->
        let l1 = callhd alleles1 fpt1 rs re rc in
        let l2 = callhd alleles2 fpt2 rs re rc in
        printf "%s\ts %s\t%c\t%s\t%d\t%s\t%d\n%!"
        readname
          rp
          (char_of_two_ls l1.Aap.llhd l2.Aap.llhd)
          (ParPHMM.Lp.to_string l1.Aap.llhd)
          l1.Aap.position
          (ParPHMM.Lp.to_string l2.Aap.llhd)
          l2.Aap.position;
      end
  | Pa.Soi (Ml.PairedDependent _) ->
      eprintf "%s not paired dependent!" readname
  | Pa.Pr _ ->
      eprintf "%s not paired!" readname

let () =
  printf "read\ts_o_p\tstate\tl: %s\tp: %s\tl %s\tp: %s\n%!"
    a1 a1 a2 a2;
  Fastq.fold_paired_both
    ~specific_reads
    ~init:()
    ~f:(fun () r1 r2 -> Pd.Fastq_items.paired_untimed r1 r2 ~k:paired)
    ~ff:(fun () r -> Pd.Fastq_items.single_utimed r ~k:(single "1"))
    ~fs:(fun () r -> Pd.Fastq_items.single_utimed r ~k:(single "2"))
    file1
    file2
  |> ignore
