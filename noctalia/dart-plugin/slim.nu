# Projects `dart run filter --detailed` output (~142KB for 30 runs) down to the
# few fields the panel renders (~10KB), so noctalia's Luau json.decode stays far
# under the 25ms script-callback budget. Reads the full JSON array on stdin
# (hence `nu --stdin`), writes a compact array on stdout.
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
