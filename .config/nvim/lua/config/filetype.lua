vim.filetype.add({
	filename = {
		[".gitlab-ci.yml"] = "yaml.gitlab",
		[".gitlab-ci.yaml"] = "yaml.gitlab",
	},
	pattern = {
		-- Ansible role files.
		[".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",

		-- Ansible playbooks.
		[".*/site%.ya?ml"] = "yaml.ansible",

		-- Inventory files.
		[".*/inventory/.*/hosts%.ya?ml"] = "yaml.ansible",

		-- Extensionless inventory variables.
		[".*/inventory/.*/group_vars/.*"] = "yaml.ansible",
		[".*/inventory/.*/host_vars/.*"] = "yaml.ansible",
	},
})
