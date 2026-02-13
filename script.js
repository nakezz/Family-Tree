// Set up the SVG canvas
const width = document.getElementById('chart').clientWidth;
const height = document.getElementById('chart').clientHeight;

const svgEl = d3.select("#chart").append("svg")
    .attr("width", width)
    .attr("height", height);

const container = svgEl.append("g");

svgEl.call(d3.zoom().on("zoom", (event) => {
    container.attr("transform", event.transform);
}));

// Fetch data from the Prolog backend
fetch('/data')
    .then(response => response.json())
    .then(data => {
        const rawNodes = data.nodes;
        const rawLinks = data.links;

        // ========== DETECT COUPLES ==========
        const childToParents = {};
        rawLinks.forEach(link => {
            if (!childToParents[link.target]) childToParents[link.target] = [];
            childToParents[link.target].push({ id: link.source, type: link.type });
        });

        // Find unique couples
        const coupleMap = {};  // "a-b" -> { p1, p2 }
        const personToCouple = {};  // person_id -> couple_key
        Object.values(childToParents).forEach(parents => {
            if (parents.length === 2) {
                const sorted = [parents[0].id, parents[1].id].sort();
                const key = sorted.join(' & ');
                if (!coupleMap[key]) {
                    coupleMap[key] = { id: key, p1: sorted[0], p2: sorted[1] };
                }
                personToCouple[sorted[0]] = key;
                personToCouple[sorted[1]] = key;
            }
        });

        // ========== BUILD MERGED NODES ==========
        const mergedIntoCouple = new Set();
        Object.values(coupleMap).forEach(c => {
            mergedIntoCouple.add(c.p1);
            mergedIntoCouple.add(c.p2);
        });

        const displayNodes = [];

        // Add couple nodes
        Object.values(coupleMap).forEach(c => {
            const p1Data = rawNodes.find(n => n.id === c.p1);
            const p2Data = rawNodes.find(n => n.id === c.p2);
            displayNodes.push({
                id: c.id,
                isCouple: true,
                p1: c.p1,
                p2: c.p2,
                p1Gender: p1Data ? p1Data.gender : 'unknown',
                p2Gender: p2Data ? p2Data.gender : 'unknown'
            });
        });

        // Add individual nodes (not part of any couple)
        rawNodes.forEach(n => {
            if (!mergedIntoCouple.has(n.id)) {
                displayNodes.push({
                    id: n.id,
                    isCouple: false,
                    gender: n.gender
                });
            }
        });

        // ========== BUILD MERGED LINKS ==========
        // Remap both source and target to couple node if applicable
        const displayLinks = [];
        const linkSet = new Set();
        rawLinks.forEach(link => {
            let sourceId = personToCouple[link.source] || link.source;
            let targetId = personToCouple[link.target] || link.target;
            // Don't link a node to itself (e.g. couple to same couple)
            if (sourceId === targetId) return;
            const key = sourceId + '->' + targetId;
            if (!linkSet.has(key)) {
                linkSet.add(key);
                displayLinks.push({
                    source: sourceId,
                    target: targetId,
                    type: 'child'
                });
            }
        });

        // ========== COMPUTE GENERATIONS ==========
        const generation = {};
        displayNodes.forEach(n => { generation[n.id] = -1; });

        // Build child set to find roots
        const childIds = new Set(displayLinks.map(l => l.target));
        displayNodes.forEach(n => {
            if (!childIds.has(n.id)) {
                generation[n.id] = 0;
            }
        });

        let changed = true;
        let iterations = 0;
        while (changed && iterations < 100) {
            changed = false;
            iterations++;
            displayLinks.forEach(link => {
                const srcGen = generation[link.source];
                if (srcGen >= 0) {
                    const newGen = srcGen + 1;
                    if (generation[link.target] < newGen) {
                        generation[link.target] = newGen;
                        changed = true;
                    }
                }
            });
        }

        // Fix any still-unassigned nodes
        displayNodes.forEach(n => {
            if (generation[n.id] < 0) generation[n.id] = 0;
        });

        const genSpacing = 160;
        displayNodes.forEach(n => {
            n.genY = 60 + generation[n.id] * genSpacing;
        });

        // ========== FORCE SIMULATION ==========
        const simulation = d3.forceSimulation(displayNodes)
            .force("link", d3.forceLink(displayLinks).id(d => d.id).distance(100).strength(0.6))
            .force("charge", d3.forceManyBody().strength(-250))
            .force("x", d3.forceX(width / 2).strength(0.05))
            .force("y", d3.forceY(d => d.genY).strength(1.5))
            .force("collide", d3.forceCollide().radius(d => d.isCouple ? 60 : 30));

        // ========== DRAW LINKS ==========
        const link = container.append("g")
            .selectAll("line")
            .data(displayLinks)
            .enter().append("line")
            .attr("stroke", "#999")
            .attr("stroke-width", 1.5)
            .attr("stroke-opacity", 0.5);

        // ========== DRAW NODES ==========
        const node = container.append("g")
            .selectAll("g")
            .data(displayNodes)
            .enter().append("g")
            .call(d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended));

        // --- Draw couple nodes (pill/capsule shape) ---
        node.filter(d => d.isCouple).each(function (d) {
            const g = d3.select(this);
            const pillW = 110, pillH = 36, r = pillH / 2;

            // Background pill
            g.append("rect")
                .attr("x", -pillW / 2)
                .attr("y", -pillH / 2)
                .attr("width", pillW)
                .attr("height", pillH)
                .attr("rx", r)
                .attr("ry", r)
                .attr("fill", "#2c2c3e")
                .attr("stroke", "#e8a838")
                .attr("stroke-width", 2.5);

            // Left circle (p1)
            g.append("circle")
                .attr("cx", -pillW / 2 + r + 2)
                .attr("cy", 0)
                .attr("r", 11)
                .attr("fill", d.p1Gender === 'male' ? "#4a90e2" : "#ff6b6b")
                .attr("stroke", "#fff")
                .attr("stroke-width", 1.5);

            // Right circle (p2)
            g.append("circle")
                .attr("cx", pillW / 2 - r - 2)
                .attr("cy", 0)
                .attr("r", 11)
                .attr("fill", d.p2Gender === 'male' ? "#4a90e2" : "#ff6b6b")
                .attr("stroke", "#fff")
                .attr("stroke-width", 1.5);

            // Heart or link symbol in center
            g.append("text")
                .attr("x", 0)
                .attr("y", 4)
                .attr("text-anchor", "middle")
                .attr("font-size", "12px")
                .text("♥")
                .attr("fill", "#e8a838");

            // Label below
            g.append("text")
                .attr("y", pillH / 2 + 14)
                .attr("text-anchor", "middle")
                .attr("font-size", "11px")
                .attr("font-weight", "600")
                .attr("fill", "#444")
                .text(d.p1 + " & " + d.p2);
        });

        // --- Draw individual nodes ---
        node.filter(d => !d.isCouple).each(function (d) {
            const g = d3.select(this);

            g.append("circle")
                .attr("r", 12)
                .attr("fill", d.gender === 'male' ? "#4a90e2" : (d.gender === 'female' ? "#ff6b6b" : "#ccc"))
                .attr("stroke", "#fff")
                .attr("stroke-width", 2.5);

            g.append("text")
                .attr("dx", 16)
                .attr("dy", ".35em")
                .attr("font-size", "12px")
                .attr("font-weight", "500")
                .attr("fill", "#333")
                .text(d.id);
        });

        // ========== LEGEND ==========
        const legend = container.append("g")
            .attr("transform", "translate(20, 20)");

        // Couple example
        const lg1 = legend.append("g");
        lg1.append("rect")
            .attr("x", 0).attr("y", 0).attr("width", 30).attr("height", 16)
            .attr("rx", 8).attr("ry", 8)
            .attr("fill", "#2c2c3e").attr("stroke", "#e8a838").attr("stroke-width", 1.5);
        lg1.append("text")
            .attr("x", 36).attr("y", 12).attr("font-size", "11px").attr("fill", "#666")
            .text("Married couple");

        // Male
        const lg2 = legend.append("g").attr("transform", "translate(0, 24)");
        lg2.append("circle").attr("cx", 8).attr("cy", 8).attr("r", 7)
            .attr("fill", "#4a90e2").attr("stroke", "#fff").attr("stroke-width", 1.5);
        lg2.append("text")
            .attr("x", 36).attr("y", 12).attr("font-size", "11px").attr("fill", "#666")
            .text("Male");

        // Female
        const lg3 = legend.append("g").attr("transform", "translate(0, 48)");
        lg3.append("circle").attr("cx", 8).attr("cy", 8).attr("r", 7)
            .attr("fill", "#ff6b6b").attr("stroke", "#fff").attr("stroke-width", 1.5);
        lg3.append("text")
            .attr("x", 36).attr("y", 12).attr("font-size", "11px").attr("fill", "#666")
            .text("Female");

        // ========== TICK ==========
        simulation.on("tick", () => {
            link
                .attr("x1", d => d.source.x)
                .attr("y1", d => d.source.y)
                .attr("x2", d => d.target.x)
                .attr("y2", d => d.target.y);

            node
                .attr("transform", d => `translate(${d.x},${d.y})`);
        });

        function dragstarted(event, d) {
            if (!event.active) simulation.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
        }

        function dragged(event, d) {
            d.fx = event.x;
            d.fy = event.y;
        }

        function dragended(event, d) {
            if (!event.active) simulation.alphaTarget(0);
            d.fx = null;
            d.fy = null;
        }
    })
    .catch(error => console.error('Error loading data:', error));

// ========== TERMINAL ==========
const termInput = document.getElementById('term-input');
const terminalOutput = document.getElementById('terminal-output');

document.getElementById('terminal').addEventListener('click', () => {
    termInput.focus();
});

termInput.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') {
        const query = termInput.value;
        if (!query) return;

        addToTerminal(`?- ${query}`, 'user-query');
        termInput.value = '';

        fetch('/ask', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query: query }),
        })
            .then(response => response.json())
            .then(data => {
                if (data.answer) {
                    if (data.answer === "true.") {
                        addToTerminal("true.", "prolog-true");
                    } else if (data.answer === "false.") {
                        addToTerminal("false.", "prolog-false");
                    } else {
                        addToTerminal(data.answer, "prolog-result");
                    }
                } else if (data.error) {
                    addToTerminal(`ERROR: ${data.error}`, "prolog-error");
                }
            })
            .catch(error => {
                addToTerminal(`ERROR: ${error.message}`, "prolog-error");
            });
    }
});

function addToTerminal(text, className) {
    const div = document.createElement('div');
    div.className = `message ${className || ''}`;
    div.textContent = text;
    terminalOutput.appendChild(div);
    terminalOutput.scrollTop = terminalOutput.scrollHeight;
}
