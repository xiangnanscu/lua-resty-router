import getCommand from './getCommand'


export default function generateReadme({
  projectName,
  packageManager,
}) {
  const commandFor = (scriptName: string, args?: string) =>
    getCommand(packageManager, scriptName, args)

  let readme = `# ${projectName}

This template should help get you started developing with xiangnanscu/lua-resty-router.

`
  let npmScriptsDescriptions = `
## Start server

\`\`\`sh
${commandFor('start')}
\`\`\`

## Test routes

\`\`\`sh
curl http://localhost:8080
\`\`\`

## Add routes

Go to \`api\` folder, there're some files already. Add your own routes in there.

`
  readme += npmScriptsDescriptions

  return readme
}
