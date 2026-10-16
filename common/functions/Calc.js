.pragma library

// Arithmetic for the search pill, without eval: + - * / % ^, parentheses,
// unary minus, decimals, pi, e and a few functions. Returns null when the
// text is not an expression worth answering.

const FUNCTIONS = {
    sqrt: Math.sqrt,
    abs: Math.abs,
    sin: Math.sin,
    cos: Math.cos,
    tan: Math.tan,
    ln: Math.log,
    log: Math.log10,
    round: Math.round,
    floor: Math.floor,
    ceil: Math.ceil
};

const CONSTANTS = { pi: Math.PI, e: Math.E };

function tokenize(text) {
    const tokens = [];
    const re = /\s*(?:(\d+(?:[.,]\d+)?|\.\d+)|([a-z]+)|(\*\*|[-+*/%^()×÷]))/gy;
    let match;
    let index = 0;
    while (index < text.length) {
        re.lastIndex = index;
        match = re.exec(text);
        if (!match) {
            if (/^\s*$/.test(text.slice(index)))
                break;
            return null;
        }
        index = re.lastIndex;
        if (match[1] !== undefined)
            tokens.push({ type: "num", value: Number(match[1].replace(",", ".")) });
        else if (match[2] !== undefined)
            tokens.push({ type: "name", value: match[2] });
        else {
            let op = match[3];
            if (op === "**") op = "^";
            if (op === "×") op = "*";
            if (op === "÷") op = "/";
            tokens.push({ type: "op", value: op });
        }
    }
    return tokens;
}

function evaluate(text) {
    const source = `${text ?? ""}`.trim().replace(/^=\s*/, "").toLowerCase();
    if (source.length === 0 || source.length > 200)
        return null;
    const tokens = tokenize(source);
    if (!tokens || tokens.length === 0)
        return null;
    // A bare number or word is not a calculation.
    const hasOperator = tokens.some(t => t.type === "op" && t.value !== "(" && t.value !== ")") || tokens.some(t => t.type === "name" && FUNCTIONS[t.value]);
    if (!hasOperator)
        return null;

    let pos = 0;
    const peek = () => tokens[pos];
    const take = () => tokens[pos++];

    function primary() {
        const t = take();
        if (!t)
            throw new Error("end");
        if (t.type === "num")
            return t.value;
        if (t.type === "name") {
            if (CONSTANTS[t.value] !== undefined)
                return CONSTANTS[t.value];
            const fn = FUNCTIONS[t.value];
            if (!fn)
                throw new Error("name");
            const next = peek();
            if (next && next.type === "op" && next.value === "(") {
                take();
                const v = expression();
                expect(")");
                return fn(v);
            }
            return fn(unary());
        }
        if (t.value === "(") {
            const v = expression();
            expect(")");
            return v;
        }
        throw new Error("token");
    }

    function expect(op) {
        const t = take();
        if (!t || t.type !== "op" || t.value !== op)
            throw new Error("expect");
    }

    function unary() {
        const t = peek();
        if (t && t.type === "op" && (t.value === "-" || t.value === "+")) {
            take();
            const v = unary();
            return t.value === "-" ? -v : v;
        }
        return power();
    }

    function power() {
        const base = primary();
        const t = peek();
        if (t && t.type === "op" && t.value === "^") {
            take();
            return Math.pow(base, unary());
        }
        return base;
    }

    function term() {
        let v = unary();
        for (;;) {
            const t = peek();
            if (!t || t.type !== "op" || (t.value !== "*" && t.value !== "/" && t.value !== "%"))
                break;
            take();
            const rhs = unary();
            if (t.value === "*") v *= rhs;
            else if (t.value === "/") v /= rhs;
            else v %= rhs;
        }
        return v;
    }

    function expression() {
        let v = term();
        for (;;) {
            const t = peek();
            if (!t || t.type !== "op" || (t.value !== "+" && t.value !== "-"))
                break;
            take();
            const rhs = term();
            v = t.value === "+" ? v + rhs : v - rhs;
        }
        return v;
    }

    try {
        const value = expression();
        if (pos !== tokens.length || !Number.isFinite(value))
            return null;
        return value;
    } catch (e) {
        return null;
    }
}

function format(value) {
    if (!Number.isFinite(value))
        return "";
    if (Number.isInteger(value) && Math.abs(value) < 1e15)
        return `${value}`;
    return `${Number(value.toPrecision(12))}`;
}
