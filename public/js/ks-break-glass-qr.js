// ============================================================================
// File: C:\laragon\www\kiezsingles\public\js\ks-break-glass-qr.js
// Changed: 09-02-2026 01:38
// Purpose: Local (offline) QR generator + renderer for Break-Glass otpauth URIs
// ============================================================================

/*
  Minimal, self-contained QR generator (Canvas), no external API calls.

  Usage (next step in web.php):
    window.KSBreakGlassQR.renderCanvas(canvasEl, otpauthUri, 220);

  Notes:
  - Error correction: M
  - Output: Canvas (black/white)
*/

(function () {
    "use strict";

    // -------------------------
    // Minimal QR encoder
    // -------------------------
    // This is a compact QR implementation adapted for embedding (no deps).
    // Supports Byte mode, version auto-fit up to a reasonable size for otpauth URIs.

    const QR_EC_LEVEL = {
        L: 1,
        M: 0,
        Q: 3,
        H: 2,
    };

    const QR_MODE = {
        BYTE: 4,
    };

    const PAD0 = 0xec;
    const PAD1 = 0x11;

    function QRBitBuffer() {
        this.buffer = [];
        this.length = 0;
    }
    QRBitBuffer.prototype = {
        get: function (index) {
            const bufIndex = Math.floor(index / 8);
            return ((this.buffer[bufIndex] >>> (7 - index % 8)) & 1) === 1;
        },
        put: function (num, length) {
            for (let i = 0; i < length; i++) {
                this.putBit(((num >>> (length - i - 1)) & 1) === 1);
            }
        },
        putBit: function (bit) {
            const bufIndex = Math.floor(this.length / 8);
            if (this.buffer.length <= bufIndex) {
                this.buffer.push(0);
            }
            if (bit) {
                this.buffer[bufIndex] |= (0x80 >>> (this.length % 8));
            }
            this.length++;
        },
    };

    function QR8BitByte(data) {
        this.mode = QR_MODE.BYTE;
        this.data = data;
        this.parsed = [];
        for (let i = 0; i < this.data.length; i++) {
            const code = this.data.charCodeAt(i);
            this.parsed.push(code & 0xff);
        }
    }
    QR8BitByte.prototype = {
        getLength: function () {
            return this.parsed.length;
        },
        write: function (buffer) {
            for (let i = 0; i < this.parsed.length; i++) {
                buffer.put(this.parsed[i], 8);
            }
        },
    };

    // Galois field (256)
    const EXP_TABLE = new Array(256);
    const LOG_TABLE = new Array(256);
    (function initGalois() {
        for (let i = 0; i < 8; i++) EXP_TABLE[i] = 1 << i;
        for (let i = 8; i < 256; i++) {
            EXP_TABLE[i] =
                EXP_TABLE[i - 4] ^
                EXP_TABLE[i - 5] ^
                EXP_TABLE[i - 6] ^
                EXP_TABLE[i - 8];
        }
        for (let i = 0; i < 255; i++) LOG_TABLE[EXP_TABLE[i]] = i;
    })();

    function gfMul(x, y) {
        if (x === 0 || y === 0) return 0;
        return EXP_TABLE[(LOG_TABLE[x] + LOG_TABLE[y]) % 255];
    }

    function QRPolynomial(num, shift) {
        let offset = 0;
        while (offset < num.length && num[offset] === 0) offset++;
        this.num = new Array(num.length - offset + (shift || 0));
        for (let i = 0; i < num.length - offset; i++) {
            this.num[i] = num[i + offset];
        }
    }
    QRPolynomial.prototype = {
        get: function (index) {
            return this.num[index];
        },
        getLength: function () {
            return this.num.length;
        },
        multiply: function (e) {
            const num = new Array(this.getLength() + e.getLength() - 1);
            for (let i = 0; i < num.length; i++) num[i] = 0;
            for (let i = 0; i < this.getLength(); i++) {
                for (let j = 0; j < e.getLength(); j++) {
                    num[i + j] ^= gfMul(this.get(i), e.get(j));
                }
            }
            return new QRPolynomial(num, 0);
        },
        mod: function (e) {
            if (this.getLength() - e.getLength() < 0) {
                return this;
            }
            const ratio = LOG_TABLE[this.get(0)] - LOG_TABLE[e.get(0)];
            const num = this.num.slice();
            for (let i = 0; i < e.getLength(); i++) {
                num[i] ^= EXP_TABLE[(LOG_TABLE[e.get(i)] + ratio + 255) % 255];
            }
            return new QRPolynomial(num, 0).mod(e);
        },
    };

    function getErrorCorrectPolynomial(errorCorrectLength) {
        let a = new QRPolynomial([1], 0);
        for (let i = 0; i < errorCorrectLength; i++) {
            a = a.multiply(new QRPolynomial([1, EXP_TABLE[i]], 0));
        }
        return a;
    }

    // RS blocks table (versions 1-10, level M only) for otpauth URIs.
    // Enough for typical otpauth strings; auto-fit picks smallest that fits.
    const RS_BLOCKS_M = {
        1:  [{ totalCount: 26, dataCount: 16 }],
        2:  [{ totalCount: 44, dataCount: 28 }],
        3:  [{ totalCount: 70, dataCount: 44 }],
        4:  [{ totalCount: 100, dataCount: 64 }],
        5:  [{ totalCount: 134, dataCount: 86 }],
        6:  [{ totalCount: 172, dataCount: 108 }],
        7:  [{ totalCount: 196, dataCount: 124 }],
        8:  [{ totalCount: 242, dataCount: 154 }],
        9:  [{ totalCount: 292, dataCount: 182 }],
        10: [{ totalCount: 346, dataCount: 216 }],
    };

    function getLengthInBits(mode, type, version) {
        // Byte mode
        if (version >= 1 && version < 10) return 8;
        return 16;
    }

    function createData(version, dataList) {
        const rsBlocks = RS_BLOCKS_M[version];
        const buffer = new QRBitBuffer();

        for (let i = 0; i < dataList.length; i++) {
            const data = dataList[i];
            buffer.put(data.mode, 4);
            buffer.put(data.getLength(), getLengthInBits(data.mode, 0, version));
            data.write(buffer);
        }

        // calc total data count
        let totalDataCount = 0;
        for (let i = 0; i < rsBlocks.length; i++) {
            totalDataCount += rsBlocks[i].dataCount;
        }

        // terminator
        if (buffer.length + 4 <= totalDataCount * 8) {
            buffer.put(0, 4);
        }

        // pad to byte
        while (buffer.length % 8 !== 0) {
            buffer.putBit(false);
        }

        // pad bytes
        while (buffer.buffer.length < totalDataCount) {
            buffer.put(PAD0, 8);
            if (buffer.buffer.length >= totalDataCount) break;
            buffer.put(PAD1, 8);
        }

        return createBytes(buffer, rsBlocks);
    }

    function createBytes(buffer, rsBlocks) {
        let offset = 0;

        const maxDcCount = 0;
        const maxEcCount = 0;

        const dcdata = [];
        const ecdata = [];

        let maxDataCount = 0;
        let maxEcCount2 = 0;

        for (let r = 0; r < rsBlocks.length; r++) {
            const dcCount = rsBlocks[r].dataCount;
            const ecCount = rsBlocks[r].totalCount - dcCount;

            maxDataCount = Math.max(maxDataCount, dcCount);
            maxEcCount2 = Math.max(maxEcCount2, ecCount);

            dcdata[r] = new Array(dcCount);
            for (let i = 0; i < dcdata[r].length; i++) {
                dcdata[r][i] = 0xff & buffer.buffer[i + offset];
            }
            offset += dcCount;

            const rsPoly = getErrorCorrectPolynomial(ecCount);
            const rawPoly = new QRPolynomial(dcdata[r], rsPoly.getLength() - 1);
            const modPoly = rawPoly.mod(rsPoly);

            ecdata[r] = new Array(rsPoly.getLength() - 1);
            for (let i = 0; i < ecdata[r].length; i++) {
                const modIndex = i + modPoly.getLength() - ecdata[r].length;
                ecdata[r][i] = modIndex >= 0 ? modPoly.get(modIndex) : 0;
            }
        }

        const totalCodeCount = rsBlocks.reduce((sum, b) => sum + b.totalCount, 0);
        const data = new Array(totalCodeCount);
        let index = 0;

        for (let i = 0; i < maxDataCount; i++) {
            for (let r = 0; r < rsBlocks.length; r++) {
                if (i < dcdata[r].length) {
                    data[index++] = dcdata[r][i];
                }
            }
        }

        for (let i = 0; i < maxEcCount2; i++) {
            for (let r = 0; r < rsBlocks.length; r++) {
                if (i < ecdata[r].length) {
                    data[index++] = ecdata[r][i];
                }
            }
        }

        return data;
    }

    function QRCodeModel(version) {
        this.version = version;
        this.moduleCount = 0;
        this.modules = null;
        this.dataCache = null;
        this.dataList = [];
    }

    QRCodeModel.prototype = {
        addData: function (data) {
            this.dataList.push(new QR8BitByte(data));
            this.dataCache = null;
        },
        isDark: function (row, col) {
            if (row < 0 || this.moduleCount <= row || col < 0 || this.moduleCount <= col) {
                return false;
            }
            return this.modules[row][col];
        },
        getModuleCount: function () {
            return this.moduleCount;
        },
        make: function () {
            this.makeImpl(false, this.getBestMaskPattern());
        },
        makeImpl: function (test, maskPattern) {
            this.moduleCount = this.version * 4 + 17;
            this.modules = new Array(this.moduleCount);
            for (let row = 0; row < this.moduleCount; row++) {
                this.modules[row] = new Array(this.moduleCount);
                for (let col = 0; col < this.moduleCount; col++) {
                    this.modules[row][col] = null;
                }
            }

            this.setupPositionProbePattern(0, 0);
            this.setupPositionProbePattern(this.moduleCount - 7, 0);
            this.setupPositionProbePattern(0, this.moduleCount - 7);
            this.setupTimingPattern();
            this.setupTypeInfo(test, maskPattern);

            if (this.version >= 2) {
                this.setupPositionAdjustPattern();
            }

            if (this.dataCache == null) {
                this.dataCache = createData(this.version, this.dataList);
            }

            this.mapData(this.dataCache, maskPattern);
        },
        setupPositionProbePattern: function (row, col) {
            for (let r = -1; r <= 7; r++) {
                if (row + r <= -1 || this.moduleCount <= row + r) continue;
                for (let c = -1; c <= 7; c++) {
                    if (col + c <= -1 || this.moduleCount <= col + c) continue;
                    if (
                        (0 <= r && r <= 6 && (c === 0 || c === 6)) ||
                        (0 <= c && c <= 6 && (r === 0 || r === 6)) ||
                        (2 <= r && r <= 4 && 2 <= c && c <= 4)
                    ) {
                        this.modules[row + r][col + c] = true;
                    } else {
                        this.modules[row + r][col + c] = false;
                    }
                }
            }
        },
        getBestMaskPattern: function () {
            let minLostPoint = 0;
            let pattern = 0;

            for (let i = 0; i < 8; i++) {
                this.makeImpl(true, i);
                const lostPoint = this.getLostPoint();
                if (i === 0 || minLostPoint > lostPoint) {
                    minLostPoint = lostPoint;
                    pattern = i;
                }
            }
            return pattern;
        },
        setupTimingPattern: function () {
            for (let i = 8; i < this.moduleCount - 8; i++) {
                if (this.modules[i][6] != null) continue;
                this.modules[i][6] = (i % 2 === 0);
                if (this.modules[6][i] != null) continue;
                this.modules[6][i] = (i % 2 === 0);
            }
        },
        setupPositionAdjustPattern: function () {
            // versions 2-10: simple table
            const posTable = {
                2: [6, 18],
                3: [6, 22],
                4: [6, 26],
                5: [6, 30],
                6: [6, 34],
                7: [6, 22, 38],
                8: [6, 24, 42],
                9: [6, 26, 46],
                10: [6, 28, 50],
            };
            const pos = posTable[this.version] || [];
            for (let i = 0; i < pos.length; i++) {
                for (let j = 0; j < pos.length; j++) {
                    const row = pos[i];
                    const col = pos[j];
                    if (this.modules[row][col] != null) continue;
                    this.setupPositionAdjustPatternImpl(row - 2, col - 2);
                }
            }
        },
        setupPositionAdjustPatternImpl: function (row, col) {
            for (let r = 0; r < 5; r++) {
                for (let c = 0; c < 5; c++) {
                    if (
                        r === 0 || r === 4 ||
                        c === 0 || c === 4 ||
                        (r === 2 && c === 2)
                    ) {
                        this.modules[row + r][col + c] = true;
                    } else {
                        this.modules[row + r][col + c] = false;
                    }
                }
            }
        },
        setupTypeInfo: function (test, maskPattern) {
            const data = (QR_EC_LEVEL.M << 3) | maskPattern;
            const bits = getBCHTypeInfo(data);

            for (let i = 0; i < 15; i++) {
                const mod = (!test && ((bits >> i) & 1) === 1);
                if (i < 6) {
                    this.modules[i][8] = mod;
                } else if (i < 8) {
                    this.modules[i + 1][8] = mod;
                } else {
                    this.modules[this.moduleCount - 15 + i][8] = mod;
                }
            }

            for (let i = 0; i < 15; i++) {
                const mod = (!test && ((bits >> i) & 1) === 1);
                if (i < 8) {
                    this.modules[8][this.moduleCount - i - 1] = mod;
                } else if (i < 9) {
                    this.modules[8][15 - i - 1 + 1] = mod;
                } else {
                    this.modules[8][15 - i - 1] = mod;
                }
            }

            this.modules[this.moduleCount - 8][8] = (!test);
        },
        mapData: function (data, maskPattern) {
            let inc = -1;
            let row = this.moduleCount - 1;
            let bitIndex = 7;
            let byteIndex = 0;

            for (let col = this.moduleCount - 1; col > 0; col -= 2) {
                if (col === 6) col--;

                while (true) {
                    for (let c = 0; c < 2; c++) {
                        if (this.modules[row][col - c] == null) {
                            let dark = false;
                            if (byteIndex < data.length) {
                                dark = (((data[byteIndex] >>> bitIndex) & 1) === 1);
                            }
                            const mask = getMask(maskPattern, row, col - c);
                            if (mask) dark = !dark;
                            this.modules[row][col - c] = dark;

                            bitIndex--;
                            if (bitIndex === -1) {
                                byteIndex++;
                                bitIndex = 7;
                            }
                        }
                    }
                    row += inc;
                    if (row < 0 || this.moduleCount <= row) {
                        row -= inc;
                        inc = -inc;
                        break;
                    }
                }
            }
        },
        getLostPoint: function () {
            const moduleCount = this.moduleCount;
            let lostPoint = 0;

            // Level 1: adjacent modules in row/column in same color
            for (let row = 0; row < moduleCount; row++) {
                for (let col = 0; col < moduleCount; col++) {
                    let sameCount = 0;
                    const dark = this.isDark(row, col);
                    for (let r = -1; r <= 1; r++) {
                        if (row + r < 0 || moduleCount <= row + r) continue;
                        for (let c = -1; c <= 1; c++) {
                            if (col + c < 0 || moduleCount <= col + c) continue;
                            if (r === 0 && c === 0) continue;
                            if (dark === this.isDark(row + r, col + c)) sameCount++;
                        }
                    }
                    if (sameCount > 5) {
                        lostPoint += (3 + sameCount - 5);
                    }
                }
            }

            // Level 2: blocks of modules in same color
            for (let row = 0; row < moduleCount - 1; row++) {
                for (let col = 0; col < moduleCount - 1; col++) {
                    let count = 0;
                    if (this.isDark(row, col)) count++;
                    if (this.isDark(row + 1, col)) count++;
                    if (this.isDark(row, col + 1)) count++;
                    if (this.isDark(row + 1, col + 1)) count++;
                    if (count === 0 || count === 4) lostPoint += 3;
                }
            }

            // Level 3: finder-like patterns
            for (let row = 0; row < moduleCount; row++) {
                for (let col = 0; col < moduleCount - 6; col++) {
                    if (
                        this.isDark(row, col) &&
                        !this.isDark(row, col + 1) &&
                        this.isDark(row, col + 2) &&
                        this.isDark(row, col + 3) &&
                        this.isDark(row, col + 4) &&
                        !this.isDark(row, col + 5) &&
                        this.isDark(row, col + 6)
                    ) {
                        lostPoint += 40;
                    }
                }
            }
            for (let col = 0; col < moduleCount; col++) {
                for (let row = 0; row < moduleCount - 6; row++) {
                    if (
                        this.isDark(row, col) &&
                        !this.isDark(row + 1, col) &&
                        this.isDark(row + 2, col) &&
                        this.isDark(row + 3, col) &&
                        this.isDark(row + 4, col) &&
                        !this.isDark(row + 5, col) &&
                        this.isDark(row + 6, col)
                    ) {
                        lostPoint += 40;
                    }
                }
            }

            // Level 4: balance of dark/light
            let darkCount = 0;
            for (let col = 0; col < moduleCount; col++) {
                for (let row = 0; row < moduleCount; row++) {
                    if (this.isDark(row, col)) darkCount++;
                }
            }

            const ratio = Math.abs((100 * darkCount) / moduleCount / moduleCount - 50) / 5;
            lostPoint += ratio * 10;

            return lostPoint;
        },
    };

    function getBCHTypeInfo(data) {
        let d = data << 10;
        while (getBCHDigit(d) - getBCHDigit(0x537) >= 0) {
            d ^= (0x537 << (getBCHDigit(d) - getBCHDigit(0x537)));
        }
        return ((data << 10) | d) ^ 0x5412;
    }

    function getBCHDigit(data) {
        let digit = 0;
        while (data !== 0) {
            digit++;
            data >>>= 1;
        }
        return digit;
    }

    function getMask(maskPattern, i, j) {
        switch (maskPattern) {
            case 0: return (i + j) % 2 === 0;
            case 1: return i % 2 === 0;
            case 2: return j % 3 === 0;
            case 3: return (i + j) % 3 === 0;
            case 4: return (Math.floor(i / 2) + Math.floor(j / 3)) % 2 === 0;
            case 5: return ((i * j) % 2 + (i * j) % 3) === 0;
            case 6: return (((i * j) % 2 + (i * j) % 3) % 2) === 0;
            case 7: return (((i * j) % 3 + (i + j) % 2) % 2) === 0;
            default: return false;
        }
    }

    function chooseVersionForBytes(byteLen) {
        for (let v = 1; v <= 10; v++) {
            const blocks = RS_BLOCKS_M[v];
            const cap = blocks.reduce((sum, b) => sum + b.dataCount, 0);
            // Byte mode overhead: mode(4) + len(8/16) + terminator/padding, approximate with +4 bytes slack
            if (byteLen + 4 <= cap) return v;
        }
        return 10;
    }

    function renderToCanvas(canvas, text, sizePx) {
        const data = String(text || "");
        const byteLen = new QR8BitByte(data).getLength();
        const version = chooseVersionForBytes(byteLen);

        const qr = new QRCodeModel(version);
        qr.addData(data);
        qr.make();

        const count = qr.getModuleCount();
        const size = Math.max(120, Math.min(600, parseInt(sizePx, 10) || 220));
        const ctx = canvas.getContext("2d", { alpha: false });

        canvas.width = size;
        canvas.height = size;

        ctx.clearRect(0, 0, size, size);
        ctx.fillStyle = "#fff";
        ctx.fillRect(0, 0, size, size);

        const tile = size / count;
        ctx.fillStyle = "#000";

        for (let r = 0; r < count; r++) {
            for (let c = 0; c < count; c++) {
                if (qr.isDark(r, c)) {
                    const x = Math.floor(c * tile);
                    const y = Math.floor(r * tile);
                    const w = Math.ceil((c + 1) * tile) - x;
                    const h = Math.ceil((r + 1) * tile) - y;
                    ctx.fillRect(x, y, w, h);
                }
            }
        }
    }

    window.KSBreakGlassQR = {
        renderCanvas: function (canvasEl, otpauthUri, sizePx) {
            if (!canvasEl) return;
            renderToCanvas(canvasEl, otpauthUri, sizePx || 220);
        },
    };
})();
