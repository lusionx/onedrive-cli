import * as yargs from 'yargs'
import * as token from './lib/token'
import * as drives from './lib/drives'
import * as fs from 'fs'
import * as os from 'os'
import { join as pathjoin, basename } from 'path'

const GRAPH = 'https://graph.microsoft.com/v1.0'
const TMP_FILE = pathjoin(os.tmpdir(), 'odrive.json')

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
    .command('get <id>', 'download file', (cmd) => {
        return cmd.positional('id', {
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
            console.log(`curl -o ${JSON.stringify(ip)} '${it.webUrl}'`)
        }
    })
    .command('del <id>', 'delete remote file', (cmd) => {
        return cmd.positional('id', {
            type: 'string',
        })
    }, async (argv) => {
        let id = argv.id as string
        if (id.startsWith('+')) {
            const ss: string[] = JSON.parse(fs.readFileSync(TMP_FILE).toString())
            id = ss[+id]
        }
        console.log('DEL', id)
        const info = await token.getToken()
        await drives.itemDel(GRAPH, info.access_token, id)
    })
    .command('put <file>', 'upload file', (cmd) => {
        return cmd.positional('file', {
            describe: 'local path',
        }).positional('path', {
            alias: 'p',
            describe: 'remote path',
        })
    }, async (argv) => {
        const fpath = argv.file as string
        const st = await token.fsStat(fpath)
        if (!st) return console.log('not exists', argv.file)
        console.log('PUT', argv.file, argv.path)
        const info = await token.getToken()
        const sesson = await drives.uploadSession(GRAPH, info.access_token, fpath)
        await drives.uploadIter(sesson.uploadUrl, fs.openSync(fpath, 'r'), st.size)
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
