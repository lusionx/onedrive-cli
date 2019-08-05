import * as yargs from 'yargs'
import * as token from './lib/token'
import * as drives from './lib/drives'

const GRAPH = 'https://graph.microsoft.com/v1.0'

const argv = yargs.usage('Usage $0 <cmd>')
    .command('auth', 'show auth url', (cmd) => {
        return cmd.positional('key', {
            describe: 'client key',
        }).positional('secret', {
            describe: 'client secret',
        }).positional('code', {
            describe: 'code from url after auth'
        })
    }, async (argv) => {
        if (argv.code) {
            await token.exToken(argv.code as string, argv.key as string, argv.secret as string)
        } else {
            return token.AuthUrl(argv.key as string, 'offline_access files.readwrite.all')
        }
    })
    .command('drive', 'show dirives', (cmd) => {
        return cmd.positional('user', {
            alias: 'u',
            default: '/me/drive',
        })
    }, async (argv) => {
        const info = await token.getToken()
        const dv = await drives.meDrive(GRAPH, info.access_token)
        console.log('drive %j', dv)
    })
    .command('item', 'show items', (cmd) => {
        return cmd.positional('path', {
            alias: 'p',
            default: '/',
        })
    }, async (argv) => {
        const info = await token.getToken()
        const dv = await drives.itemList(GRAPH, info.access_token, argv.path)
        dv.forEach(e => {
            console.log(e.id, e.name, e.size)
            if (e.file) console.log('   ', e.file.mimeType)
            if (e.folder) console.log('    child', e.folder.childCount)
        })
    })
    .option('log', {
        default: 'info',
    })
    .help()
    .argv

console.log('argv %j', argv)



process.on("unhandledRejection", (error) => {
    console.dir(error)
    const { response, config } = error
    if (config && response) {
        return console.error({ config, data: response.data })
    }
    console.error(error)
})
