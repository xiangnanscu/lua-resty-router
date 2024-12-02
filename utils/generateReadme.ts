import getCommand from './getCommand'


export default function generateReadme({
  projectName,
  packageManager,
}) {
  const commandFor = (scriptName: string, args?: string) =>
    getCommand(packageManager, scriptName, args)

  let readme = `# ${projectName}

This template should help get you started developing with xiangnanscu/lua-resty-router.

## Project Setup

`

  let npmScriptsDescriptions = `\`\`\`sh
${commandFor('install')}
\`\`\`

### Start server

\`\`\`sh
${commandFor('start')}
\`\`\`
`
  readme += npmScriptsDescriptions

  return readme
}
