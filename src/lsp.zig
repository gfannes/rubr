const std = @import("std");

pub const dto = @import("lsp/dto.zig");

const strng = @import("strng.zig");

pub const Error = error{
    UnexpectedKey,
    CouldNotReadEOH,
    CouldNotReadContentLength,
    UnexpectedCountForOptional,
    ExpectedValidRequest,
    ExpectedValidId,
};

pub const Server = struct {
    const Self = @This();
    const Buffer = std.ArrayList(u8);

    in: *std.Io.Reader,
    out: *std.Io.Writer,
    log: ?*std.Io.Writer,
    a: std.mem.Allocator,

    content_length: ?usize = null,
    content: Buffer = .{},

    aa: std.heap.ArenaAllocator,
    request: ?dto.Request = null,

    pub fn init(in: *std.Io.Reader, out: *std.Io.Writer, log: ?*std.Io.Writer, a: std.mem.Allocator) Self {
        return Self{
            .in = in,
            .out = out,
            .log = log,
            .a = a,
            .aa = std.heap.ArenaAllocator.init(a),
        };
    }
    pub fn deinit(self: *Self) void {
        self.content.deinit(self.a);
        self.aa.deinit();
    }

    pub fn receive(self: *Self) !*const dto.Request {
        self.aa.deinit();
        self.aa = std.heap.ArenaAllocator.init(self.a);

        try self.readHeader();
        try self.readContent();

        if (self.log) |log|
            try log.print("[Request]({s})\n", .{self.content.items});
        self.request = (try std.json.parseFromSlice(dto.Request, self.aa.allocator(), self.content.items, .{})).value;

        return &(self.request orelse unreachable);
    }

    pub fn send(self: *Self, result: anytype) !void {
        const request = self.request orelse return Error.ExpectedValidRequest;
        const id = request.id orelse return Error.ExpectedValidId;
        defer self.request = null;

        const Result = @TypeOf(result);

        const response = sw: switch (@typeInfo(Result)) {
            .null => {
                const Response = dto.Response(bool);
                break :sw Response{ .id = id, .result = null };
            },
            else => {
                const Response = dto.Response(Result);
                break :sw Response{ .id = id, .result = &result };
            },
        };

        try self.content.resize(self.a, 0);

        var acc = std.Io.Writer.Allocating.fromArrayList(self.a, &self.content);
        defer acc.deinit();

        try std.json.Stringify.value(response, .{}, &acc.writer);

        if (self.log) |log|
            try log.print("[Response]({s})\n", .{self.content.items});

        try self.out.print("Content-Length: {}\r\n\r\n{s}", .{ self.content.items.len, self.content.items });
    }

    fn readHeader(self: *Self) !void {
        self.content_length = null;

        try self.content.resize(self.a, 0);
        var acc = std.Io.Writer.Allocating.fromArrayList(self.a, &self.content);
        defer acc.deinit();

        const size = try self.in.streamDelimiter(&acc.writer, '\r');
        std.debug.assert(size == self.content.items.len);
        const line = self.content.items;

        if (self.log) |log|
            try log.print("[Line](size:{s})\n", .{line});

        var str = strng.Strange{ .content = line };

        if (str.popStr("Content-Length:")) {
            _ = str.popMany(' ');
            self.content_length = str.popInt(usize) orelse return Error.CouldNotReadContentLength;
        } else return Error.UnexpectedKey;

        // Read the remaining "\n\r\n"
        var buf: [3]u8 = undefined;
        try self.in.readSliceAll(&buf);
        if (!std.mem.eql(u8, &buf, "\n\r\n")) return Error.CouldNotReadEOH;
    }

    fn readContent(self: *Self) !void {
        if (self.content_length) |cl| {
            try self.content.resize(self.a, cl);
            try self.in.readSliceAll(self.content.items);
        }
    }
};

pub const Client = struct {
    const Self = @This();
    const Buffer = std.ArrayList(u8);

    in: std.fs.File.Reader,
    out: std.fs.File.Writer,
    log: ?std.fs.File.Writer,
    a: std.mem.Allocator,

    content_length: ?usize = null,
    content: Buffer,

    aa: std.heap.ArenaAllocator,
    request: ?dto.Request = null,

    res_initialize: dto.Response(dto.InitializeResult) = undefined,

    pub fn init(in: std.fs.File.Reader, out: std.fs.File.Writer, log: ?std.fs.File.Writer, a: std.mem.Allocator) Self {
        return Self{
            .in = in,
            .out = out,
            .log = log,
            .a = a,
            .content = Buffer.init(a),
            .aa = std.heap.ArenaAllocator.init(a),
        };
    }
    pub fn deinit(self: *Self) void {
        self.content.deinit();
        self.aa.deinit();
    }

    pub fn send(self: *Self, request: dto.Request) !void {
        try self.content.resize(0);
        try std.json.stringify(request, .{}, self.content.writer());
        if (self.log) |log|
            try log.print("[Request]({s})\n", .{self.content.items});

        try self.out.print("Content-Length: {}\r\n\r\n{s}", .{ self.content.items.len, self.content.items });
    }

    pub fn receive(self: *Self, T: type) !*const T {
        self.aa.deinit();
        self.aa = std.heap.ArenaAllocator.init(self.a);

        try self.readHeader();
        try self.readContent();

        if (self.log) |log|
            try log.print("[Response]({s})\n", .{self.content.items});

        const resp = self.response_(T);
        resp.* = (try std.json.parseFromSlice(T, self.aa.allocator(), self.content.items, .{})).value;

        return resp;
    }

    fn response_(self: *Self, T: type) *T {
        if (dto.Response(T) == @TypeOf(self.res_initialize)) {
            return &self.res_initialize;
        }
        unreachable;
    }
};

test "lsp" {
    const ut = std.testing;

    const request =
        \\{
        \\  "jsonrpc": "2.0",
        \\  "method": "initialize",
        \\  "params": {
        \\    "capabilities": {
        \\      "general": {
        \\        "positionEncodings": [
        \\          "utf-8",
        \\          "utf-32",
        \\          "utf-16"
        \\        ]
        \\      },
        \\      "textDocument": {
        \\        "codeAction": {
        \\          "codeActionLiteralSupport": {
        \\            "codeActionKind": {
        \\              "valueSet": [
        \\                "",
        \\                "quickfix",
        \\                "refactor",
        \\                "refactor.extract",
        \\                "refactor.inline",
        \\                "refactor.rewrite",
        \\                "source",
        \\                "source.organizeImports"
        \\              ]
        \\            }
        \\          },
        \\          "dataSupport": true,
        \\          "disabledSupport": true,
        \\          "isPreferredSupport": true,
        \\          "resolveSupport": {
        \\            "properties": [
        \\              "edit",
        \\              "command"
        \\            ]
        \\          }
        \\        },
        \\        "completion": {
        \\          "completionItem": {
        \\            "deprecatedSupport": true,
        \\            "insertReplaceSupport": true,
        \\            "resolveSupport": {
        \\              "properties": [
        \\                "documentation",
        \\                "detail",
        \\                "additionalTextEdits"
        \\              ]
        \\            },
        \\            "snippetSupport": true,
        \\            "tagSupport": {
        \\              "valueSet": [
        \\                1
        \\              ]
        \\            }
        \\          },
        \\          "completionItemKind": {}
        \\        },
        \\        "formatting": {
        \\          "dynamicRegistration": false
        \\        },
        \\        "hover": {
        \\          "contentFormat": [
        \\            "markdown"
        \\          ]
        \\        },
        \\        "inlayHint": {
        \\          "dynamicRegistration": false
        \\        },
        \\        "publishDiagnostics": {
        \\          "tagSupport": {
        \\            "valueSet": [
        \\              1,
        \\              2
        \\            ]
        \\          },
        \\          "versionSupport": true
        \\        },
        \\        "rename": {
        \\          "dynamicRegistration": false,
        \\          "honorsChangeAnnotations": false,
        \\          "prepareSupport": true
        \\        },
        \\        "signatureHelp": {
        \\          "signatureInformation": {
        \\            "activeParameterSupport": true,
        \\            "documentationFormat": [
        \\              "markdown"
        \\            ],
        \\            "parameterInformation": {
        \\              "labelOffsetSupport": true
        \\            }
        \\          }
        \\        }
        \\      },
        \\      "window": {
        \\        "workDoneProgress": true
        \\      },
        \\      "workspace": {
        \\        "applyEdit": true,
        \\        "configuration": true,
        \\        "didChangeConfiguration": {
        \\          "dynamicRegistration": false
        \\        },
        \\        "didChangeWatchedFiles": {
        \\          "dynamicRegistration": true,
        \\          "relativePatternSupport": false
        \\        },
        \\        "executeCommand": {
        \\          "dynamicRegistration": false
        \\        },
        \\        "fileOperations": {
        \\          "didRename": true,
        \\          "willRename": true
        \\        },
        \\        "inlayHint": {
        \\          "refreshSupport": false
        \\        },
        \\        "symbol": {
        \\          "dynamicRegistration": false
        \\        },
        \\        "workspaceEdit": {
        \\          "documentChanges": true,
        \\          "failureHandling": "abort",
        \\          "normalizesLineEndings": false,
        \\          "resourceOperations": [
        \\            "create",
        \\            "rename",
        \\            "delete"
        \\          ]
        \\        },
        \\        "workspaceFolders": true
        \\      }
        \\    },
        \\    "clientInfo": {
        \\      "name": "helix",
        \\      "version": "25.1 (911ecbb6)"
        \\    },
        \\    "processId": 547208,
        \\    "rootPath": "/home/geertf/chimp",
        \\    "rootUri": "file:///home/geertf/chimp",
        \\    "workspaceFolders": [
        \\      {
        \\        "name": "chimp",
        \\        "uri": "file:///home/geertf/chimp"
        \\      }
        \\    ]
        \\  },
        \\  "id": 0
        \\}
    ;
    var aa = std.heap.ArenaAllocator.init(ut.allocator);
    defer aa.deinit();
    const p = try std.json.parseFromSlice(dto.Request, aa.allocator(), request, .{});
    std.debug.print("p: {}\n", .{p.value});

    {
        const Result = dto.InitializeResult;
        const result: Result = .{
            .capabilities = dto.ServerCapabilities{ .workspaceSymbolProvider = true },
            .serverInfo = dto.ServerInfo{
                .name = "chimp",
                .version = "0.0.0",
            },
        };

        const Response = dto.Response(Result);
        const response = Response{
            .id = 42,
            .result = &result,
        };

        var out = std.Io.Writer.Allocating.init(ut.allocator);
        defer out.deinit();

        try std.json.Stringify.value(response, .{}, &out.writer);
        const str = try out.toOwnedSlice();
        defer ut.allocator.free(str);
        std.debug.print("response {s}\n", .{str});
    }
}
