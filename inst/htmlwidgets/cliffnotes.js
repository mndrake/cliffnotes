var test;

HTMLWidgets.widget({

  name: 'cliffnotes',

  type: 'output',

  factory: function(el, width, height) {
    // TODO: define shared variables for this instance
    return {

      renderValue: function(x) {

        ReactDOM.render(
            React.createElement(DataFrameSummary, {data: x.data}),
            document.getElementById(el.id)
        );

      },

      resize: function(width, height) {
        // TODO: code to re-render the widget with a new size
      }
    };
  }
});

var DataFrameSummary = React.createClass({
    updateDimensions: function() {
        var w = window,
            d = document,
            documentElement = d.documentElement,
            body = d.getElementsByTagName('body')[0],
            width = w.innerWidth || documentElement.clientWidth || body.clientWidth,
            height = w.innerHeight|| documentElement.clientHeight|| body.clientHeight;
        d3.select("#data-frame-summary").style("height", height + 'px');
    },
    componentWillMount: function() {
        this.updateDimensions();
    },
    componentDidMount: function() {
        this.updateDimensions();
        window.addEventListener("resize", this.updateDimensions);
    },
    componentWillUnmount: function() {
        window.removeEventListener("resize", this.updateDimensions);
    }, render: function() {
        var data = this.props.data;
        test = data;
        var columns = data[0],
            N = data[4],
            P = [];
        columns.forEach(function (n, e) {
            var L =  data[1][n][0],
                I = data[2][n],
                hist = data[3][n],
                unique = data[6][n][0],
                maxL = data[8][n][0],
                minL = data[9][n][0],
                s = 0,
                _ = [[0]];
            console.log(n, L);
            L == "integer" || L == "numeric" ? P.push(React.createElement(NumericTile, {
                    key: n,
                    value: n,
                    idx: e,
                    col: n,
                    dt: L,
                    stat: I,
                    hist: hist,
                    nna: s,
                    outlier: _,
                    nrow: N
                }, null)
            ) : L == "character" ? P.push(React.createElement(FactorTile, {
                    key: n,
                    value: n,
                    idx: e,
                    col: n,
                    dt: L,
                    stat: I,
                    nuniq: unique,
                    minlen: minL,
                    maxlen: maxL,
                    hist: I,
                    nna: s,
                    outlier: _,
                    nrow: N
                }, null)
            ) : L == "POSIXct,POSIXt" ? P.push(React.createElement(DateTile, {
                    key: n,
                    value: n,
                    idx: e,
                    col: n,
                    dt: "POSIXct",
                    stat: I,
                    hist: hist,
                    nna: s,
                    outlier: _,
                    nrow: N
                }, null)
            ) : ({});
        });

        return React.createElement("div", {className: "data-frame-summary", id: "data-frame-summary"},
                React.createElement("h1", {}, "Summary"), P);
    }
});

var FactorTile = React.createClass({
    getInitialState: function () {
        return {}
    }, _scientificFmtr: d3.format(".4e"),
    _humanReadableFmtr: d3.format(",.8g"),
    getNumberOfNAs: function (e) {
        var t = e[e.length - 1].split(":"), n = /^NA/.test(t[0].trim()) ? parseInt(t[1]) : 0;
        return n
    }, renderHealthBar: function (e, t, n, a) {
        var o = n && 0 !== n ? n / t * 100 : 0,
            i = a && 0 !== a ? a / t * 100 : 0,
            s = 100 - o - i,
            l = {width: this.formatNumber(s) + "%"},
            c = {width: this.formatNumber(o) + "%"},
            u = {width: this.formatNumber(i) + "%"},
            d = function (e, t) {
                return function (n) {
                    var r = n.nativeEvent.offsetX;
                    r = 100 > r ? r + 10 : r - 100,
                        $elem = $("#" + e).html(t).css("left", r + "px").addClass("show"),
                        $(n.target).css("opacity", "0.5")
                }
            },
            p = function (e) {
                return function (t) {
                    $elem = $("#" + e).removeClass("show"), $(t.target).css("opacity", "1")
                }
            },
            m = [];
        return m.push(React.createElement("td", {
            className: "clean",
            style: l,
            key: this.props.idx,
            onMouseEnter: d(e, "Clean: " + l.width),
            onMouseLeave: p(e)
        })), o > 0 && m.push(React.createElement("td", {
            className: "nas",
            style: c,
            onMouseEnter: d(e, "NAs: " + c.width),
            onMouseLeave: p(e)
        })), i > 0 && m.push(React.createElement("td", {
            className: "outlier",
            style: u,
            onMouseEnter: d(e, "Outlier: " + u.width),
            onMouseLeave: p(e)
        })), React.createElement("div", null,
            React.createElement("table", null,
                React.createElement("tbody", null,
                    React.createElement("tr", null, m))),
            React.createElement("div", {
                className: "balloon",
                id: e
            }))
    }, formatNumber: function (e) {
        if (isNaN(e))return e;
        if (e = parseFloat(e), Math.abs(e) >= 1e8 || Math.abs(e) < .01 && 0 !== e)
            return this._scientificFmtr(e);
        var t = this._humanReadableFmtr(e);
        return -1 === t.indexOf(".") ? t : t.replace(/0*$/, "").replace(/\.$/, "")
    }, renderTop6Data: function (e, t) {
            var n = [], i = e.map(function (e) {
                return {text: e}
            }), s = i.filter(function (e) {
                return !isNaN(e.text.substring(e.text.lastIndexOf(":") + 1))
            });
            s.forEach(function (e) {
                e.val = parseInt(e.text.substring(e.text.lastIndexOf(":") + 1))
            });
            var l = s.sort(function (e, t) {
                return t.val - e.val
            }), c = -1;
            if (l.forEach(function (e, t) {
                    /^\(Other\)/.test(e.text) && (c = t)
                }), -1 !== c) {
                var u = l.splice(c, 1);
                l = l.concat(u)
            }
            var d = d3.max(l, function (e) {
                return /^\(Other\)/.test(e.text) ? 0 : e.val
            }), p = d3.scale.linear().domain([0, d]).range([0, 100]);
            return n = l.map(function (e, n) {
                var i = {width: /^\(Other\)/.test(e.text) ? "0%" :
                    p(parseInt(e.text.substring(e.text.lastIndexOf(":") + 1))) + "%"},
                    s = e.text.split(":"),
                    l = s.pop().replace(/^[\s]*/, "").replace(/[\s]*$/, ""),
                    c = s.join(":"),
                    u = c + " (" + l + ")",
                    d = t ? t[n] : React.createElement("pre", null, u),
                    h = React.createElement("div", {className: "summary-view-tile-graph-bar"},
                        React.createElement("div", {className: "summary-view-tile-graph-bar-bar", style: i}),
                        React.createElement("div", {className: "summary-view-tile-graph-bar-text"}, u));
                return h
            })
    }, render: function () {
        console.log('creating tile:', this.props.col);
        try {
            var e = this.props.col,
                t = this.props.stat;
            if (!t) return null;
            var n = (
                this.props.dt,
                this.props.dt.split(",").pop()),
                a = this.props.nrow, o = this.formatNumber(this.props.nuniq),
                i = this.formatNumber(this.props.maxlen),
                s = this.formatNumber(this.props.minlen),
                l = this.getNumberOfNAs(t),
                c = (l / a * 100).toFixed(2) + "%",
                u = [];
            u = "first6rows" === t[0] ? this.renderFirst6Rows(t) : this.renderTop6Data(t);
            var d = this.renderHealthBar("summary-view-tile-" + this.props.idx, a, l, 0),
                p = this;
            return (
                React.createElement("div", {className: "summary-view-tile", style: {width:250, height:360}},
                    React.createElement("div", {className: "summary-view-tile-header"},
                        React.createElement("div", {className: "summary-view-tile-header-label"},
                            React.createElement("span", {}, this.props.value),
                            React.createElement("span", {})),
                        React.createElement("div",
                            {className: "summary-view-tile-header-data-type", title: this.props.dt},
                            React.createElement("span", {}, this.props.dt),
                            React.createElement("span", {}))),
                    React.createElement("div", {className: "summary-view-tile-graph", style: {height: 180}},
                        React.createElement("div", {className: "summary-view-tile-graph-bar-area"}, u)),
                    React.createElement("div", {className: "summary-view-tile-health-bar"}, d),
                    React.createElement("div", {className: "summary-view-tile-stats"},
                        React.createElement("table", {},
                            React.createElement("tbody", {},
                                React.createElement("tr", {},
                                    React.createElement("td", {className: 0 === l ? "" : "nas"},
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-label"}, "NAs"),
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-value"},
                                            this.formatNumber(l)," (",c,")"))),
                                React.createElement("tr", {},
                                    React.createElement("td", {},
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-label"}, "Unique"),
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-value"}, this.formatNumber(o)))),
                                React.createElement("tr", {},
                                    React.createElement("td", {},
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-label"}, "Min Length"),
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-value"}, this.formatNumber(s)))),
                                React.createElement("tr", {},
                                    React.createElement("td", {},
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-label"}, "Max Length"),
                                        React.createElement("span",
                                            {className: "summary-view-tile-stats-value"}, this.formatNumber(i)))))))))
        } catch (h) {
            return console.error("Failed to render summary for column: " + e, h) //, this.renderErrorTile()
        }
    }
});


var NumericTile = React.createClass({
    _scientificFmtr: d3.format(".4e"),
    _humanReadableFmtr: d3.format(",.8g"),
    getNumberOfNAs: function (e) {
        var t = e[e.length - 1].split(":"), n = /^NA/.test(t[0].trim()) ? parseInt(t[1]) : 0;
        return n
    },
    renderHealthBar: function (e, t, n, a) {
        var o = n && 0 !== n ? n / t * 100 : 0,
            i = a && 0 !== a ? a / t * 100 : 0,
            s = 100 - o - i,
            l = {width: this.formatNumber(s) + "%"},
            c = {width: this.formatNumber(o) + "%"},
            u = {width: this.formatNumber(i) + "%"},
            d = function (e, t) {
                return function (n) {
                    var r = n.nativeEvent.offsetX;
                    r = 100 > r ? r + 10 : r - 100,
                        $elem = $("#" + e).html(t).css("left", r + "px").addClass("show"),
                        $(n.target).css("opacity", "0.5")
                }
            },
            p = function (e) {
                return function (t) {
                    $elem = $("#" + e).removeClass("show"), $(t.target).css("opacity", "1")
                }
            },
            m = [];
        return m.push(React.createElement("td", {
            className: "clean",
            style: l,
            key: this.props.idx,
            onMouseEnter: d(e, "Clean: " + l.width),
            onMouseLeave: p(e)
        })), o > 0 && m.push(React.createElement("td", {
            className: "nas",
            style: c,
            onMouseEnter: d(e, "NAs: " + c.width),
            onMouseLeave: p(e)
        })), i > 0 && m.push(React.createElement("td", {
            className: "outlier",
            style: u,
            onMouseEnter: d(e, "Outlier: " + u.width),
            onMouseLeave: p(e)
        })), React.createElement("div", null,
            React.createElement("table", null,
                React.createElement("tbody", null,
                    React.createElement("tr", null, m))),
            React.createElement("div", {
            className: "balloon",
            id: e
        }))
    }, formatNumber: function (e) {
        if (isNaN(e))return e;
        if (e = parseFloat(e), Math.abs(e) >= 1e8 || Math.abs(e) < .01 && 0 !== e)
            return this._scientificFmtr(e);
        var t = this._humanReadableFmtr(e);
        return -1 === t.indexOf(".") ? t : t.replace(/0*$/, "").replace(/\.$/, "")
    }, _renderHistogram: function (e, t, n, r, a, o) {
        var i = {
            top: 5,
            right: 2,
            bottom: 14,
            left: 2 },
            s = t - i.left - i.right,
            c = n - i.top - i.bottom,
            u = d3.scale.ordinal().rangeRoundBands([0, s], .1),
            d = d3.scale.linear().range([c, 0]),
            p = (d3.svg.axis().scale(u).ticks(2).orient("bottom"),
                 d3.svg.axis().scale(d).orient("left"),
                 d3.svg.area().interpolate("basis").x(
                     function (e) {return u(e[0])}).y0(c).y1(
                     function (e) {return d(e[1])}),
                 d3.select(e)
                     .append("svg")
                     .attr("width", s + i.left + i.right)
                     .attr("height", c + i.top + i.bottom + 2)),
            m = p.append("g")
                .attr("transform", "translate(" + i.left + "," + (c + i.top + i.bottom) + ")");
        m.append("text")
            .attr("class", "label")
            .attr("x", 5).attr("text-anchor", "start")
            .text(r.min), m.append("text")
            .attr("class", "label")
            .attr("x", s - 5)
            .attr("text-anchor", "end")
            .text(r.max);
        var h = p.append("g").attr("transform", "translate(" + i.left + "," + i.top + ")"),
            f = d3.select(e).append("div").attr("class", "tooltip").style("position", "absolute").style("opacity", 0);
        u.domain(r.mids), d.domain([0, d3.max(r.counts)]);
        var g, v = [];
        for (g = 0; g < r.mids.length; g++){
            v.push(o + ":" + r.breaks[g] + ":" + r.breaks[g + 1] + ":" + r.counts[g])
        }
        var b = d3.zip(r.mids, r.counts, v), y = this;
        h.selectAll(".bar").data(b).enter().append("rect").attr("class", "bar").attr("id", function (e) {
            return e[2]
        }).attr("x", function (e) {
            return u(e[0])
        }).attr("y", function (e) {
            return c - d(e[1]) < 1 ? c - 1 : d(e[1])
        }).attr("height", function (e) {
            return c - d(e[1]) < 1 ? 1 : c - d(e[1])
        }).attr("width", u.rangeBand()).on("mouseover", function () {
            var e = this.id.split(":"),
                t = "<table><tbody><tr><td>Range:</td><td>" + y.formatNumber(e[1]) + " - " + y.formatNumber(e[2]) + "</td></tr>";
            t += "<tr><td>Count:</td><td>" + y.formatNumber(e[3]) + "</td></tr></tbody></table>",
                f.html(t).style("left", "10px").style("top", d3.event.offsetY - 60 + "px"),
                f.transition().duration(20).style("opacity", .9), d3.select(this).classed({selected: !0})
        }).on("mouseout", function (e) {
            f.transition().duration(10).style("opacity", 0), d3.select(this).classed({selected: !1})
        });
        console.log('building chart');
    }, _componentDidMount: function (e, t) {
    var n = document.getElementById("hist-area-" + this.props.col);
    if (n) {
        var r = this.props.hist;
        this._renderHistogram(n, n.clientWidth, n.clientHeight, {
            breaks: r[0],
            counts: r[1],
            mids: r[2],
            min: e,
            max: t
        }, null, "hist-" + this.props.idx);
    }
    }, componentDidMount: function(){
        var e = this.props.stat,
            minN = this.formatNumber(e[0].split(":")[1]),
            maxN = this.formatNumber(e[5].split(":")[1]);
        this._componentDidMount(minN, maxN);
    },
    render: function() {
        var colName = this.props.col,
            t = this.props.dt,
            n = (this.formatNumber(this.props.outlier[0][0]), this.props.stat),
            nRow = this.props.nrow,
            nNAs = this.getNumberOfNAs(n),
            i = (nNAs / nRow * 100).toFixed(2) + "%",
            minN = n[0].split(":")[1],
            medianN = (n[1].split(":")[1], n[2].split(":")[1]),
            averageN = n[3].split(":")[1],
            maxN = (n[4].split(":")[1], n[5].split(":")[1]),
            d = (this.props.hist, this.renderHealthBar("summary-view-tile-" + colName, nRow, nNAs, this.props.outlier[0][0])),
            p = this;

        return (

        React.createElement("div", {className: "summary-view-tile", style: {width:250, height:360}},
            React.createElement("div", {className: "summary-view-tile-header"},
                React.createElement("div", {className: "summary-view-tile-header-label"},
                    React.createElement("span", {}, this.props.value),
                    React.createElement("span", {})),
                React.createElement("div",
                    {className: "summary-view-tile-header-data-type", title: this.props.dt},
                    React.createElement("span", {}, this.props.dt),
                    React.createElement("span", {}))),
            React.createElement("div", {className: "summary-view-tile-graph", style: {height: 180}},
                React.createElement("div", {className: "summary-view-tile-hist-area", id: "hist-area-" + colName})),
            React.createElement("div", {className: "summary-view-tile-health-bar"}, d),
            React.createElement("div", {className: "summary-view-tile-stats"},
                React.createElement("table", {},
                    React.createElement("tbody", {},
                        React.createElement("tr", {},
                            React.createElement("td", {className: 0 === nNAs ? "" : "nas"},
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-label"}, "NAs"),
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-value"},
                                    this.formatNumber(nNAs)," (",i,")"))),
                        React.createElement("tr", {},
                            React.createElement("td", {},
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-label"}, "Min"),
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-value"}, this.formatNumber(minN)))),
                        React.createElement("tr", {},
                            React.createElement("td", {},
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-label"}, "Max"),
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-value"}, this.formatNumber(maxN)))),
                        React.createElement("tr", {},
                            React.createElement("td", {},
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-label"}, "Median"),
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-value"}, this.formatNumber(medianN)))),
                        React.createElement("tr", {},
                            React.createElement("td", {},
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-label"}, "Average"),
                                React.createElement("span",
                                    {className: "summary-view-tile-stats-value"}, this.formatNumber(averageN))))
                    ))))
        )
    }
});

var DateTile = React.createClass({
    _scientificFmtr: d3.format(".4e"),
    _humanReadableFmtr: d3.format(",.8g"),
    getNumberOfNAs: function (e) {
        var t = e[e.length - 1].split(":"), n = /^NA/.test(t[0].trim()) ? parseInt(t[1]) : 0;
        return n
    },
    getInitialState: function () {
        return {}
    }, componentDidMount: function () {
        console.log('mount datetile')
        var e = document.getElementById("hist-area-" + this.props.col);
        if (e) {
            var t = (this.props.col, this.props.stat),
                n = this.props.hist,
                r = this.props.idx,
                a = this._getValue(t[0], n),
                o = this._getValue(t[5], n);
            if (!(n.length < 3)) {
                var i = n[0], s = n[1], l = n[2];
                this._renderHistogram(e, e.clientWidth, e.clientHeight, {
                    breaks: i,
                    counts: s,
                    mids: l,
                    min: a,
                    max: o
                }, null, "hist-" + r)
            }
        }
    }, formatNumber: function (e) {
        if (isNaN(e))return e;
        if (e = parseFloat(e), Math.abs(e) >= 1e8 || Math.abs(e) < .01 && 0 !== e)
            return this._scientificFmtr(e);
        var t = this._humanReadableFmtr(e);
        return -1 === t.indexOf(".") ? t : t.replace(/0*$/, "").replace(/\.$/, "")
    }, renderHealthBar: function (e, t, n, a) {
        var o = n && 0 !== n ? n / t * 100 : 0,
            i = a && 0 !== a ? a / t * 100 : 0,
            s = 100 - o - i,
            l = {width: this.formatNumber(s) + "%"},
            c = {width: this.formatNumber(o) + "%"},
            u = {width: this.formatNumber(i) + "%"},
            d = function (e, t) {
                return function (n) {
                    var r = n.nativeEvent.offsetX;
                    r = 100 > r ? r + 10 : r - 100,
                        $elem = $("#" + e).html(t).css("left", r + "px").addClass("show"),
                        $(n.target).css("opacity", "0.5")
                }
            },
            p = function (e) {
                return function (t) {
                    $elem = $("#" + e).removeClass("show"), $(t.target).css("opacity", "1")
                }
            },
            m = [];
        return m.push(React.createElement("td", {
            className: "clean",
            style: l,
            key: this.props.idx,
            onMouseEnter: d(e, "Clean: " + l.width),
            onMouseLeave: p(e)
        })), o > 0 && m.push(React.createElement("td", {
            className: "nas",
            style: c,
            onMouseEnter: d(e, "NAs: " + c.width),
            onMouseLeave: p(e)
        })), i > 0 && m.push(React.createElement("td", {
            className: "outlier",
            style: u,
            onMouseEnter: d(e, "Outlier: " + u.width),
            onMouseLeave: p(e)
        })), React.createElement("div", null,
            React.createElement("table", null,
                React.createElement("tbody", null,
                    React.createElement("tr", null, m))),
            React.createElement("div", {
                className: "balloon",
                id: e
            }))
    }, componentDidUpdate: function () {
        console.log('update datetile');
        var e = document.getElementById("hist-area-" + this.props.col);
        this._emptyHistogram(e), this.componentDidMount()
    }, _emptyHistogram: function (e) {
        d3.select(e).selectAll(".bar").on("mouseover", null).on("mouseout", null), $(e).empty()
    }, _renderHistogram: function (e, t, n, r, a, o) {
        console.log("render time histogram");
        var i = {
            top: 5,
            right: 2,
            bottom: 14,
            left: 2
        }, s = t - i.left - i.right,
            c = n - i.top - i.bottom,
            u = d3.scale.ordinal().rangeRoundBands([0, s], .1),
            d = d3.scale.linear().range([c, 0]),
            p = (d3.svg.axis().scale(u).ticks(2).orient("bottom"),
                d3.svg.axis().scale(d).orient("left"),
                d3.svg.area().interpolate("basis").x(function (e) {return u(e[0])}).y0(c).y1(function (e) {return d(e[1])}),
                d3.select(e).append("svg").attr("width", s + i.left + i.right).attr("height", c + i.top + i.bottom)),
            m = p.append("g").attr("transform", "translate(" + i.left + "," + (c + i.top + i.bottom) + ")");
        m.append("text").attr("class", "label").attr("x", 5).attr("text-anchor", "start").text(r.min),
            m.append("text").attr("class", "label").attr("x", s - 5).attr("text-anchor", "end").text(r.max);
        var h = p.append("g").attr("transform", "translate(" + i.left + "," + i.top + ")"),
            f = d3.select(e).append("div").attr("class", "tooltip").style("position", "absolute").style("opacity", 0);
        u.domain(r.mids), d.domain([0, d3.max(r.counts)]);
        var g, v = [];
        for (g = 0; g < r.mids.length; g++)v.push(o + "|" + r.mids + "|" + r.breaks[g] + "|" + r.breaks[g + 1] + "|" + r.counts[g]);
        var b = d3.zip(r.mids, r.counts, v);
        h.selectAll(".bar").data(b).enter().append("rect").attr("class", "bar").attr("id", function (e) {
            return e[2]
        }).attr("x", function (e) {
            return u(e[0])
        }).attr("y", function (e) {
            return c - d(e[1]) < 1 ? c - 1 : d(e[1])
        }).attr("height", function (e) {
            return c - d(e[1]) < 1 ? 1 : c - d(e[1])
        }).attr("width", u.rangeBand()).on("mouseover", function () {
            var e = this.id.split("|"), t = (this.label, "<table><tr><td>Range:</td><td>" + e[2] + " - " + e[3] + "</td></tr>");
            t += "<tr><td>Count:</td><td>" + e[4] + "</td></tr></table>", f.html(t).style("left", "10px").style("top", d3.event.offsetY - 60 + "px"), f.transition().duration(20).style("opacity", .9), d3.select(this).classed({selected: !0})
        }).on("mouseout", function (e) {
            f.transition().duration(10).style("opacity", 0), d3.select(this).classed({selected: !1})
        })
    }, _getValue: function (e, t) {
        if (!e)return "";
        var n = e.split(":");
        n.shift();
        var r = n.join(":");
        return t.length > 4 && "%H:%M:%S" === t[4][0] ? r.split(" ")[1].trim() : r.split(" ")[0].trim()
    }, render: function () {
        try {
            var e = this.props.col,
                t = (this.props.dt, this.props.dt.split(",").shift()),
                n = this.props.stat,
                a = this.props.nrow,
                o = this.getNumberOfNAs(n),
                i = this.props.hist,
                s = this._getValue(n[0], i),
                l = (this._getValue(n[1], i), this._getValue(n[2], i)),
                c = this._getValue(n[3], i),
                u = (this._getValue(n[4], i), this._getValue(n[5], i)),
                d = (o / a * 100).toFixed(2) + "%",
                p = this.renderHealthBar("summary-view-tile-" + e, a, o, this.props.outlier[0][0]);

            return (

            React.createElement("div", {className: "summary-view-tile", style: {width:250, height:360}},
                React.createElement("div", {className: "summary-view-tile-header"},
                    React.createElement("div", {className: "summary-view-tile-header-label"},
                        React.createElement("span", {}, this.props.value),
                        React.createElement("span", {})),
                    React.createElement("div",
                        {className: "summary-view-tile-header-data-type", title: this.props.dt},
                        React.createElement("span", {}, this.props.dt),
                        React.createElement("span", {}))),
                React.createElement("div", {className: "summary-view-tile-graph", style: {height: 180}},
                    React.createElement("div", {className: "summary-view-tile-hist-area", id: "hist-area-" + this.props.col})),
                React.createElement("div", {className: "summary-view-tile-health-bar"}, p),
                React.createElement("div", {className: "summary-view-tile-stats"},
                    React.createElement("table", {},
                        React.createElement("tbody", {},
                            React.createElement("tr", {},
                                React.createElement("td", {className: 0 === o ? "" : "nas"},
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-label"}, "NAs"),
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-value"},
                                        this.formatNumber(o)," (",d,")"))),
                            React.createElement("tr", {},
                                React.createElement("td", {},
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-label"}, "Min"),
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-value"}, s))),
                            React.createElement("tr", {},
                                React.createElement("td", {},
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-label"}, "Max"),
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-value"}, u))),
                            React.createElement("tr", {},
                                React.createElement("td", {},
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-label"}, "Median"),
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-value"}, l))),
                            React.createElement("tr", {},
                                React.createElement("td", {},
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-label"}, "Average"),
                                    React.createElement("span",
                                        {className: "summary-view-tile-stats-value"}, c)))
                        ))))
            );
        } catch (f) {
            return console.error("Failed to render summary for column: " + e, f); //, this.renderErrorTile()
        }
    }
});
