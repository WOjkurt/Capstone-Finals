using System.Globalization;
using System.IO.Compression;
using System.Xml.Linq;

namespace Api.Common;

/// <summary>
/// Reads the cell text of every sheet in an .xlsx file (Excel 2007+). Enough for the registrar's lists:
/// text, numbers and inline strings; no formulas are evaluated (the saved value is used).
/// </summary>
public static class XlsxReader
{
    private static readonly XNamespace Main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private static readonly XNamespace Rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    private static readonly XNamespace PkgRel = "http://schemas.openxmlformats.org/package/2006/relationships";

    public sealed record Sheet(string Name, List<Row> Rows);

    /// <summary>One spreadsheet row; <see cref="Number"/> is the row number Excel shows.</summary>
    public sealed record Row(int Number, IReadOnlyList<string> Cells)
    {
        public string this[int i] => i < Cells.Count ? Cells[i] : string.Empty;
    }

    /// <summary>Throws <see cref="InvalidDataException"/> when the file is not an .xlsx workbook.</summary>
    public static List<Sheet> Read(Stream stream)
    {
        ZipArchive zip;
        try
        {
            zip = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: true);
        }
        catch (InvalidDataException)
        {
            throw new InvalidDataException("This is not an Excel (.xlsx) file. In Excel, use File → Save As → Excel Workbook (.xlsx).");
        }

        using (zip)
        {
            var workbook = Load(zip, "xl/workbook.xml")
                ?? throw new InvalidDataException("This is not an Excel (.xlsx) file.");
            var rels = Load(zip, "xl/_rels/workbook.xml.rels");
            var targets = rels?.Root?.Elements(PkgRel + "Relationship")
                .ToDictionary(r => (string)r.Attribute("Id")!, r => (string)r.Attribute("Target")!) ?? new();
            var shared = Load(zip, "xl/sharedStrings.xml")?.Root?.Elements(Main + "si")
                .Select(si => string.Concat(si.Descendants(Main + "t").Select(t => t.Value)))
                .ToList() ?? new List<string>();

            var result = new List<Sheet>();
            foreach (var s in workbook.Root!.Element(Main + "sheets")?.Elements(Main + "sheet") ?? [])
            {
                var name = (string?)s.Attribute("name") ?? "";
                var id = (string?)s.Attribute(Rel + "id");
                if (id == null || !targets.TryGetValue(id, out var target)) continue;
                var path = target.StartsWith('/') ? target.TrimStart('/') : "xl/" + target;
                var doc = Load(zip, path);
                if (doc == null) continue;
                result.Add(new Sheet(name, ReadRows(doc, shared)));
            }
            return result;
        }
    }

    private static List<Row> ReadRows(XDocument doc, List<string> shared)
    {
        var rows = new List<Row>();
        foreach (var r in doc.Descendants(Main + "row"))
        {
            var cells = new SortedDictionary<int, string>();
            foreach (var c in r.Elements(Main + "c"))
            {
                var col = ColumnIndex((string?)c.Attribute("r"));
                if (col < 0) col = cells.Count == 0 ? 0 : cells.Keys.Max() + 1;
                var type = (string?)c.Attribute("t");
                string value = type switch
                {
                    "s" => int.TryParse(c.Element(Main + "v")?.Value, out var i) && i < shared.Count ? shared[i] : "",
                    "inlineStr" => string.Concat(c.Descendants(Main + "t").Select(t => t.Value)),
                    _ => c.Element(Main + "v")?.Value ?? "",
                };
                cells[col] = value.Trim();
            }
            if (cells.Count == 0 || cells.Values.All(string.IsNullOrEmpty)) continue;
            var list = new string[cells.Keys.Max() + 1];
            for (int i = 0; i < list.Length; i++) list[i] = cells.TryGetValue(i, out var v) ? v : "";
            int number = int.TryParse((string?)r.Attribute("r"), out var n) ? n : rows.Count + 1;
            rows.Add(new Row(number, list));
        }
        return rows;
    }

    /// <summary>"C12" → 2 (zero-based).</summary>
    private static int ColumnIndex(string? reference)
    {
        if (string.IsNullOrEmpty(reference)) return -1;
        int n = 0, i = 0;
        for (; i < reference.Length && char.IsAsciiLetter(reference[i]); i++) n = n * 26 + char.ToUpperInvariant(reference[i]) - 'A' + 1;
        return i == 0 ? -1 : n - 1;
    }

    private static XDocument? Load(ZipArchive zip, string path)
    {
        var entry = zip.GetEntry(path);
        if (entry == null) return null;
        using var s = entry.Open();
        return XDocument.Load(s);
    }

    /// <summary>
    /// A whole number typed into Excel can come back as "2.5060208E7" or "25060208.0"; this returns "25060208".
    /// Text that is not a number is returned trimmed.
    /// </summary>
    public static string WholeNumberText(string raw)
    {
        var t = raw.Trim();
        if (t.Length > 0 && double.TryParse(t, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) &&
            d >= 0 && d < 1e15 && Math.Abs(d - Math.Round(d)) < 1e-6)
        {
            return ((long)Math.Round(d)).ToString(CultureInfo.InvariantCulture);
        }
        return t;
    }
}
