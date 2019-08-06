import * as yargs from 'yargs'
import * as token from './lib/token'
import * as drives from './lib/drives'
import * as fs from 'fs'
import { join as pathjoin } from 'path'

const GRAPH = 'https://graph.microsoft.com/v1.0'
const TMP_FILE = '/tmp/odrive.json'

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
        dv.forEach((e, ii) => {
            const ty = e.file ? e.file.mimeType : (e.folder ? 'folder/' + e.folder.childCount : 'unkonwn')
            let ss = e.size + 'B'
            if (e.size > 1024 * 1024) {
                ss = Math.ceil(e.size / 1024 / 1024) + 'M'
            } else if (e.size > 1024) {
                ss = Math.ceil(e.size / 1024) + 'K'
            }
            console.log('%d %s (%s) %s %s', ii, e.id, ss, ty, e.name)
        })
        fs.writeFile(TMP_FILE, JSON.stringify(dv.map(e => e.id)), (err) => err)
    })
    .command('get', 'download file', (cmd) => {
        return cmd.positional('id', {
            alias: 'i',
            type: 'string',
        }).positional('path', {
            alias: 'p',
        })
    }, async (argv) => {
        let id = argv.id as string
        if (id.startsWith('+')) {
            const ss: string[] = JSON.parse(fs.readFileSync(TMP_FILE).toString())
            id = ss[+id]
        }
        console.log('GET', id)
        const info = await token.getToken()
        const it = await drives.itemInfo(GRAPH, info.access_token, id)
        if (it.file) {
            let ip = argv.path as string
            ip = pathjoin(process.cwd(), ip)
            const st = await token.fsStat(ip)
            if (st) { // access
                if (st.isDirectory()) {
                    ip = pathjoin(ip, it.name)
                }
            }
            console.log('FORM', it.webUrl)
            console.log('SAVE', ip)
        }
    })
    .option('log', {
        default: 'info',
    })
    .fail((msg, error: any) => {
        if (error.isAxiosError) {
            const { response, config } = error
            return console.error({ config, data: response.data })
        }
        console.error(error)
    })
    .help()
    .argv

console.log('argv %j', argv)
