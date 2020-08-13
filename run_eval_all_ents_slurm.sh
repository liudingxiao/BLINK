#!/bin/sh
#SBATCH --output=log/%j.out
#SBATCH --error=log/%j.err
#SBATCH --partition=learnfair
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --signal=USR1
#SBATCH --mem=400000
#SBATCH --gres=gpu:8
#SBATCH --cpus-per-task=24
#SBATCH --time 3000
#SBATCH --constraint=volta32gb

# example usage
# bash run_eval_slurm.sh 64 webqsp_filtered zero_shot qa_classifier dev false 0 false
# bash run_eval_slurm.sh 64 webqsp_filtered "finetuned_webqsp;biencoder_none_false_16_2;9 qa_classifier" dev false 0 false
# bash run_eval_slurm.sh 64 webqsp_filtered "finetuned_webqsp;<model_folder>;<best_epoch>" qa_classifier dev false 0 false

# bash run_eval_slurm.sh 64 webqsp_filtered webqsp_none_biencoder qa_classifier dev false 0 false
# bash run_eval_slurm.sh 64 webqsp_filtered zeshel_none_biencoder qa_classifier dev false 0 false
# bash run_eval_slurm.sh 64 webqsp_filtered pretrain_none_biencoder qa_classifier dev false 0 false
# bash run_eval_slurm.sh 64 webqsp_filtered pretrain_all_avg_biencoder qa_classifier dev false 0 false
# bash run_eval_slurm.sh 64 webqsp_filtered 'finetuned_webqsp_all_ents;<model_dir>' joint dev false 0.25 false
# bash run_eval_slurm.sh webqsp_filtered dev 'finetuned_webqsp_all_ents;all_mention_biencoder_all_avg_true_20_true_bert_large_qa_linear' joint 0.25 100 joint_0

# bash run_eval_slurm.sh webqsp_filtered dev 'finetuned_webqsp_all_ents;all_mention_biencoder_all_avg_true_20_true_bert_large_qa_linear' joint 0.25 100 joint_0
# bash run_eval_slurm.sh webqsp_filtered dev 'finetuned_webqsp_all_ents;all_mention_biencoder_all_avg_true_20_true_false_bert_large_qa_linear' joint 0.25 100 joint_0
# bash run_eval_all_ents_slurm.sh AIDA-YAGO2 test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_false_false_bert_base_qa_linear;10' joint 0.25 100 joint_0
# srun --gpus-per-node=8 --partition=learnfair --time=3000 --cpus-per-task 80 --pty -l \
# bash run_eval_all_ents_slurm.sh _ test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_true_true_bert_large_qa_linear;6' joint 0.25 100 joint_0 64
# bash run_eval_all_ents_slurm.sh _ test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_true_true_bert_large_qa_linear;11' joint 0.25 100 joint_0 64
# bash run_eval_all_ents_slurm.sh _ test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_false_false_bert_large_qa_linear;2' joint 0.25 100 joint_0 64 'models/entity_encodings/wiki_all_ents_all_avg_true_128_false_false_bert_large_qa_linear/all.t7'
# bash run_eval_all_ents_slurm.sh _ test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_false_false_bert_base_qa_linear;10' joint 0.25 100 joint_0 64 'models/entity_encodings/wiki_all_ents_all_avg_true_128_false_false_bert_base_qa_linear/all.t7'

# bash run_eval_all_ents_slurm.sh WebQSP_EL test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_false_false_bert_base_qa_linear;10' joint 0.25 100 joint 64 'models/entity_encodings/wiki_all_ents_all_avg_true_128_false_false_bert_base_qa_linear/all.t7'
# bash run_eval_all_ents_slurm.sh WebQSP_EL test 'wiki_all_ents;all_mention_biencoder_all_avg_true_128_true_true_bert_base_qa_linear;15' joint -4.5 50 joint 1

test_questions=$1  # WebQSP_EL/AIDA-YAGO2/graphquestions_EL
subset=$2  # test/dev/train_only
model_full=$3  # zero_shot/new_zero_shot/finetuned_webqsp/finetuned_webqsp_all_ents/finetuned_graphqs/webqsp_none_biencoder/zeshel_none_biencoder/pretrain_all_avg_biencoder/
threshold=$4  # -4.5/-2.9/-inf for no pruning
top_k=$5  # 50
threshold_type=$6  # joint / top_entity_by_mention
eval_batch_size=$7  # 64
entity_encoding=$8  # file for entity encoding
debug="false"  # "true"/<anything other than "true"> (does debug_cross)
gpu=$9

export PYTHONPATH=.

IFS=';' read -ra MODEL_PARSE <<< "${model_full}"
model=${MODEL_PARSE[0]}
echo $model
echo $model_full

if [ "${eval_batch_size}" = "" ]
then
    eval_batch_size="64"
fi
save_dir_batch=""
if [ "${eval_batch_size}" = "1" ]
then
    save_dir_batch="_realtime_test"
fi

mentions_file="/checkpoint/belindali/entity_link/data/${test_questions}/tokenized/${subset}.jsonl"

threshold_args="--threshold=${threshold} --threshold_type ${threshold_type} "
if [[ ${threshold_type} = "top_entity_by_mention" ]]
then
    threshold_args="${threshold_args} --mention_threshold -0.6931"
fi
echo $threshold_args

if [ "${gpu}" = "false" ]
then
    cuda_args=""
else
    cuda_args="--use_cuda"
fi

if [ "${model}" = "finetuned_webqsp" ] || [ "${model}" = "pretrain" ] || [ "${model}" = "finetuned_webqsp_all_ents" ] || [ "${model}" = "wiki_all_ents" ]
then
    model_folder=${MODEL_PARSE[1]}  # biencoder_none_false_16_2
    echo ${model_folder}
    echo ${MODEL_PARSE[1]}
    epoch=${MODEL_PARSE[2]}  # 9
    if [[ $epoch != "" ]]
    then
        model_folder=${MODEL_PARSE[1]}/epoch_${epoch}
    fi
    if [ "${model}" = "finetuned_webqsp" ]
    then
        dir="webqsp"
        #biencoder_config=/checkpoint/belindali/entity_link/saved_models/${dir}/${MODEL_PARSE[1]}/training_params.txt
        #biencoder_model=/checkpoint/belindali/entity_link/saved_models/${dir}/${model_folder}/pytorch_model.bin
        biencoder_config=experiments/${dir}/${MODEL_PARSE[1]}/training_params.txt
        biencoder_model=experiments/${dir}/${model_folder}/pytorch_model.bin
    elif [ "${model}" = "finetuned_webqsp_all_ents" ]
    then
        dir="webqsp_all_ents"
        #biencoder_config=/checkpoint/belindali/entity_link/saved_models/${dir}/${MODEL_PARSE[1]}/training_params.txt
        #biencoder_model=/checkpoint/belindali/entity_link/saved_models/${dir}/${model_folder}/pytorch_model.bin
        biencoder_config=experiments/${dir}/${MODEL_PARSE[1]}/training_params.txt
        biencoder_model=experiments/${dir}/${model_folder}/pytorch_model.bin
    elif [ "${model}" = "wiki_all_ents" ]
    then
        dir="wiki_all_ents"
        biencoder_config=experiments/${dir}/${MODEL_PARSE[1]}/training_params.txt
        biencoder_model=experiments/${dir}/${model_folder}/pytorch_model.bin
    else
        dir="pretrain"
    fi
    if [ "${test_questions}" = "nq" ]
    then
        max_context_length_args="--max_context_length 32"
    elif [ "${test_questions}" = "triviaqa" ]
    then
        max_context_length_args="--max_context_length 256"
    fi
    if [ "${entity_encoding}" = "" ] || [ "${entity_encoding}" = "_" ]
    then
        entity_encoding=/private/home/belindali/BLINK/models/all_entities_large.t7
    fi
elif [ "${model}" = "zero_shot" ]
then
    entity_encoding=/private/home/belindali/BLINK/models/all_entities_large.t7
    biencoder_config=/private/home/belindali/BLINK/models/biencoder_wiki_large.json
    biencoder_model=/private/home/belindali/BLINK/models/biencoder_wiki_large.bin
elif [ "${model}" = "new_zero_shot" ]
then
    entity_encoding=models/all_entities_large.t7
    biencoder_config=models/biencoder_wiki_large.json
    biencoder_model=models/biencoder_wiki_large.bin
else
    entity_encoding=models/entity_encodings/${model}/all.t7
    biencoder_config=models/entity_encodings/${model}/training_params.txt
    biencoder_model=models/entity_encodings/${model}/pytorch_model.bin
fi
echo ${mentions_file}

command="python blink/main_dense_all_ents.py \
    --test_mentions ${mentions_file} \
    --test_entities models/entity.jsonl \
    --entity_catalogue models/entity.jsonl \
    --entity_encoding ${entity_encoding} \
    --biencoder_model ${biencoder_model} \
    --biencoder_config ${biencoder_config} \
    --save_preds_dir /checkpoint/belindali/entity_link/saved_preds/${test_questions}_${subset}_${model_full}_top${top_k}cands_thresh${threshold}${save_dir_batch} \
    ${threshold_args} --num_cand_mentions ${top_k} --num_cand_entities 10 \
    --eval_batch_size ${eval_batch_size} ${cuda_args} ${max_context_length_args} \
    --faiss_index hnsw --index_path models/faiss_hnsw_index.pkl"
    # --faiss_index ivfflat --index_path models/faiss_ivfflat_index.pkl"
    # --faiss_index flat --index_path models/faiss_flat_index.pkl"

echo "${command}"

# python blink/generate_candidate.py  
${command}
