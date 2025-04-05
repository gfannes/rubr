const std = @import("std");

pub const dto = @import("lsp/dto.zig");

const strange = @import("strange.zig");

pub const Error = error{
    UnexpectedKey,
    CouldNotReadEOH,
    CouldNotReadContentLength,
    CouldNotReadData,
    UnexpectedCountForOptional,
    ExpectedValidRequest,
    ExpectedValidId,
};

pub const Server = struct {
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

        try self.content.resize(0);
        try std.json.stringify(response, .{}, self.content.writer());
        if (self.log) |log|
            try log.print("[Response]({s})\n", .{self.content.items});

        try self.out.print("Content-Length: {}\r\n\r\n{s}", .{ self.content.items.len, self.content.items });
    }

    pub fn alloc(self: *Self, dst: anytype, count: usize) !AllocType(@TypeOf(dst.*)) {
        _ = self;
        const Dst = @TypeOf(dst.*);
        const typeInfo = @typeInfo(Dst);
        switch (typeInfo) {
            .optional => {
                if (count != 1) return Error.UnexpectedCountForOptional;
                dst.* = typeInfo.optional.child{};
                return &(dst.* orelse unreachable);
            },
            else => unreachable,
        }
    }

    fn AllocType(T: type) type {
        const ti = @typeInfo(T);
        switch (ti) {
            .optional => return *ti.optional.child,
            else => unreachable,
        }
    }

    fn readHeader(self: *Self) !void {
        self.content_length = null;

        try self.content.resize(1024);
        if (try self.in.readUntilDelimiterOrEof(self.content.items, '\r')) |line| {
            if (self.log) |log|
                try log.print("[Line](content:{s})\n", .{line});

            var str = strange.Strange.init(line);

            if (str.popStr("Content-Length:")) {
                _ = str.popMany(' ');
                self.content_length = str.popInt(usize) orelse return Error.CouldNotReadContentLength;
            } else return Error.UnexpectedKey;

            // Read the remaining "\n\r\n"
            try self.content.resize(3);
            if (try self.in.readAll(self.content.items) != 3) return Error.CouldNotReadEOH;
            if (!std.mem.eql(u8, self.content.items, "\n\r\n")) return Error.CouldNotReadEOH;
        }
    }

    fn readContent(self: *Self) !void {
        if (self.content_length) |cl| {
            try self.content.resize(cl);
            if (try self.in.readAll(self.content.items) != cl) return Error.CouldNotReadData;
        }
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

        var buffer = std.ArrayList(u8).init(ut.allocator);
        defer buffer.deinit();

        try std.json.stringify(response, .{}, buffer.writer());
        std.debug.print("response {s}\n", .{buffer.items});
    }
}
