const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const channelDir = path.join(root, 'test-channel');

const filesToCopy = [
    ['source/GrowthBook.brs', 'test-channel/source/GrowthBook.brs'],
    ['tests/cases.json', 'test-channel/source/cases.json'],
    ['tests/GrowthBookTestRunner.brs', 'test-channel/source/GrowthBookTestRunner.brs'],
    ['tests/TestUtilities.brs', 'test-channel/source/TestUtilities.brs'],
];

console.log('Copying SDK and test files into test-channel...');
for (const [src, dest] of filesToCopy) {
    fs.copyFileSync(path.join(root, src), path.join(root, dest));
    console.log(`  ${src} -> ${dest}`);
}

console.log('Creating pkg.zip...');
const zipPath = path.join(channelDir, 'pkg.zip');
if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath);

const entries = [];
collectFiles(channelDir, channelDir, entries);
const zipBuffer = createZip(entries);
fs.writeFileSync(zipPath, zipBuffer);
console.log(`Created ${path.relative(root, zipPath)} (${entries.length} files, ${zipBuffer.length} bytes)`);

function collectFiles(dir, baseDir, result) {
    for (const name of fs.readdirSync(dir)) {
        const full = path.join(dir, name);
        if (full === zipPath) continue;
        if (fs.statSync(full).isDirectory()) {
            collectFiles(full, baseDir, result);
        } else {
            const relative = path.relative(baseDir, full).replace(/\\/g, '/');
            result.push({ name: relative, data: fs.readFileSync(full) });
        }
    }
}

// Minimal ZIP creator (stored/uncompressed, forward-slash paths)
function createZip(files) {
    const localHeaders = [];
    const centralHeaders = [];
    let offset = 0;

    for (const file of files) {
        const nameBytes = Buffer.from(file.name, 'utf8');
        const crc = crc32(file.data);
        const size = file.data.length;

        const local = Buffer.alloc(30 + nameBytes.length);
        local.writeUInt32LE(0x04034b50, 0);
        local.writeUInt16LE(20, 4);
        local.writeUInt16LE(0, 6);
        local.writeUInt16LE(0, 8);
        local.writeUInt16LE(0, 10);
        local.writeUInt16LE(0, 12);
        local.writeUInt32LE(crc, 14);
        local.writeUInt32LE(size, 18);
        local.writeUInt32LE(size, 22);
        local.writeUInt16LE(nameBytes.length, 26);
        local.writeUInt16LE(0, 28);
        nameBytes.copy(local, 30);

        const central = Buffer.alloc(46 + nameBytes.length);
        central.writeUInt32LE(0x02014b50, 0);
        central.writeUInt16LE(20, 4);
        central.writeUInt16LE(20, 6);
        central.writeUInt16LE(0, 8);
        central.writeUInt16LE(0, 10);
        central.writeUInt16LE(0, 12);
        central.writeUInt16LE(0, 14);
        central.writeUInt32LE(crc, 16);
        central.writeUInt32LE(size, 20);
        central.writeUInt32LE(size, 24);
        central.writeUInt16LE(nameBytes.length, 28);
        central.writeUInt16LE(0, 30);
        central.writeUInt16LE(0, 32);
        central.writeUInt16LE(0, 34);
        central.writeUInt16LE(0, 36);
        central.writeUInt32LE(0, 38);
        central.writeUInt32LE(offset, 42);
        nameBytes.copy(central, 46);

        localHeaders.push(local, file.data);
        centralHeaders.push(central);
        offset += local.length + file.data.length;
    }

    const centralSize = centralHeaders.reduce((s, b) => s + b.length, 0);
    const eocd = Buffer.alloc(22);
    eocd.writeUInt32LE(0x06054b50, 0);
    eocd.writeUInt16LE(0, 4);
    eocd.writeUInt16LE(0, 6);
    eocd.writeUInt16LE(files.length, 8);
    eocd.writeUInt16LE(files.length, 10);
    eocd.writeUInt32LE(centralSize, 12);
    eocd.writeUInt32LE(offset, 16);
    eocd.writeUInt16LE(0, 20);

    return Buffer.concat([...localHeaders, ...centralHeaders, eocd]);
}

function crc32(buf) {
    let crc = 0xFFFFFFFF;
    for (let i = 0; i < buf.length; i++) {
        crc ^= buf[i];
        for (let j = 0; j < 8; j++) {
            crc = (crc >>> 1) ^ (crc & 1 ? 0xEDB88320 : 0);
        }
    }
    return (crc ^ 0xFFFFFFFF) >>> 0;
}
