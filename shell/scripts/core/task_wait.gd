class_name TaskWait
## Collecting background tasks when FORGE closes, with a time limit.
## Godot must collect every task before quitting, but a task running a command that never
## ends (a stuck network or Bluetooth tool) used to keep FORGE from closing at all: the
## console froze on Restart. Now FORGE waits at most 2.5 seconds in total, then ends its own
## process (settings are saved before closing starts).

static var _deadline := 0

static func on_exit(id: int) -> void:
	if _deadline == 0:
		_deadline = Time.get_ticks_msec() + 2500
	while not WorkerThreadPool.is_task_completed(id):
		if Time.get_ticks_msec() > _deadline:
			OS.kill(OS.get_process_id())
			return
		OS.delay_msec(10)
	WorkerThreadPool.wait_for_task_completion(id)
