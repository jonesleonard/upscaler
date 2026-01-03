################################################################################
# Upscale Video Step Function Outputs
################################################################################

output "upscale_video_state_machine_arn" {
  description = "The ARN of the Upscale Video Step Function state machine."
  value       = module.upscale_video_state_machine.state_machine_arn
}

output "upscale_video_state_machine_name" {
  description = "The name of the Upscale Video Step Function state machine."
  value       = module.upscale_video_state_machine.state_machine_name
}
