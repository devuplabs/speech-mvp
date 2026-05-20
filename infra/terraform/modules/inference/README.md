# Inference module (GKE + vLLM + Gemma 3 27B)

Provisions air-gapped-style inference per [ADR-003](../../../../docs/decisions/003-self-hosted-llm-air-gap.md):

- GKE cluster + **L4 GPU** node pool (`g2-standard-8`)
- Private nodes, **no internet egress** firewall on `gke-inference` tag
- Model weights bucket (CMEK) — sync via init container
- **vLLM** Deployment + internal `LoadBalancer` Service
- Firewall: Serverless VPC connector → vLLM port

## Before first `terraform apply`

1. **GPU quota** — `NVIDIA_L4_GPUS` in target zone (`inference_zone`).
2. **Mirror vLLM image** to Artifact Registry (no Docker Hub from private nodes):

   ```bash
   docker pull vllm/vllm-openai:latest
   docker tag vllm/vllm-openai:latest REGION-docker.pkg.dev/PROJECT/sona-sona/vllm-openai:latest
   docker push REGION-docker.pkg.dev/PROJECT/sona-sona/vllm-openai:latest
   ```

3. **Upload Gemma 3 27B IT (AWQ recommended)** to `gs://PROJECT-sona-models-JURISDICTION-ENV/gemma-3-27b-it/`  
   Hugging Face: `google/gemma-3-27b-it` (accept license on HF first).

4. Set `vllm_container_image` in `terraform.tfvars` to the pushed image URL.

## After apply

- Note `vllm_openai_base_url` output (may need a second apply once internal LB IP is assigned).
- Configure Sona API: `INFERENCE_OPENAI_BASE_URL=<output>`.

## Quantization

If using AWQ weights, add to Deployment args in Terraform when validated:

`--quantization awq`
