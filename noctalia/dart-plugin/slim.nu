# Cuts `dart run filter --detailed` JSON (~142KB for 30 runs) to the fields the
# panel renders (~10KB), keeping json.decode inside noctalia's 25ms callback
# budget. JSON array on stdin (`nu --stdin`), compact array on stdout.
def main [] {
	$in
	| from json
	| each {|r|
		let cfg = ($r.config? | default {})
		{
			id: $r.id?
			state: $r.state?
			state_info: ($r.state_info? | default "")
			created_at: $r.created_at?
			project: ($r.project_info? | default {} | get --optional project_id)
			tags: ($cfg | get --optional tags | default [])
			description: ($cfg | get --optional description)
			# A float (-1.0), or null when unset; DART schedules null as 0.
			priority: ($cfg | get --optional priority)
			git_commit: ($r.git_commit? | default "")
			state_updated_at: $r.state_updated_at?
			user_name: $r.user_name?
			clusters: (
				$r.clusters?
				| default {}
				| items {|name, c| {name: $name, state: ($c | default {} | get --optional state)} }
				| reduce --fold {} {|it, acc| $acc | insert $it.name $it.state }
			)
		}
	}
	| to json --raw
}
