import assert from 'assert'
import path from 'path'
import fs from 'fs'
import {ufs} from 'unionfs'
import {link} from 'linkfs'
import {ArgumentParser, RawDescriptionHelpFormatter} from 'argparse'
import packageJson from '../package.json'
import {TextExpander} from './expander_text'
import {XMLExpander} from './expander_xml'

// Read and process arguments
const parser = new ArgumentParser({
  description: 'A simple templating system.',
  formatter_class: RawDescriptionHelpFormatter,
  epilog: `The INPUT-PATH is a '${path.delimiter}'-separated list of directories; the directories\n` +
    'are merged, with the contents of each directory taking precedence over any\n' +
    'directories to its right.',
})
parser.add_argument('input', {metavar: 'INPUT-PATH', help: 'desired directory list to build'})
parser.add_argument('output', {metavar: 'OUTPUT-DIRECTORY', help: 'output directory'})
parser.add_argument('--path', {help: 'relative path to build [default: input directory]'})
parser.add_argument('--keep-going', {
  action: 'store_true',
  help: 'do not stop on error',
})
parser.add_argument('--expander', {
  metavar: 'EXPANDER',
  help: 'expander to use [default: %(default)s]',
  choices: ['text', 'xml'],
  default: 'text',
})
parser.add_argument('--version', {
  action: 'version',
  version: `%(prog)s ${packageJson.version}
(c) 2002-2021 Reuben Thomas <rrt@sc3d.org>
https://github.com/rrthomas/nancy/
Distributed under the GNU General Public License version 3, or (at
your option) any later version. There is no warranty.`,
})
interface Args {
  input: string;
  output: string;
  path?: string;
  verbose: boolean;
  keep_going: boolean;
  expander: string;
}
const args: Args = parser.parse_args() as Args

// Merge input directories, left as highest-priority
const inputDirs = args.input.split(path.delimiter)
const inputDir = inputDirs.shift()
assert(inputDir !== undefined)
for (const dir of inputDirs.reverse()) {
  ufs.use(link(fs, [inputDir, dir]))
}
ufs.use(fs)

// Expand input
let expander
switch (args.expander) {
  case 'text':
    expander = new TextExpander(inputDir, args.output, args.path, !args.keep_going, ufs)
    break
  case 'xml':
    expander = new XMLExpander(inputDir, args.output, args.path, !args.keep_going, ufs)
    break
  default:
    throw new Error(`unknown expander '${args.expander}'`)
}
try {
  expander.expand()
} catch (error) {
  if (process.env.DEBUG) {
    console.error(error)
  } else {
    console.error(`${path.basename(process.argv[1])}: ${error}`)
  }
  process.exitCode = 1
}
