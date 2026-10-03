// Гарантирует, что расширение собрано как форк: имя и displayName содержат fork.
// Идемпотентно, форматирование package.json не трогает (замена по строкам).
import { readFileSync, writeFileSync } from 'node:fs';

const file = new URL('../package.json', import.meta.url);
let text = readFileSync(file, 'utf8');
const before = text;

text = text.replace(/^\t"name": "glsld",$/m, '\t"name": "glsld-fork",');
text = text.replace(
	/^\t"displayName": "[^"]*",$/m,
	'\t"displayName": "glsld (fork) - GLSL Language Server",'
);

if (text !== before) {
	writeFileSync(file, text);
	console.log('fork branding applied');
} else {
	console.log('fork branding ok');
}
