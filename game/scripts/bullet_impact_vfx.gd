extends Node3D

func emit():
	$GPUParticles3D.emitting = true
	$GPUParticles3D.one_shot = true
	$GPUParticles3D/GPUParticles3D.emitting = true
	$GPUParticles3D/GPUParticles3D.one_shot = true
	$GPUParticles3D.finished.connect(queue_free)
	
