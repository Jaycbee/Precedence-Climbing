local prec_climb = {}

local var_Pattern  = '^%s*(%w[%.%w_]*)()(%(?)'  --anchor is important!
local unary_Pattern = '^%s*([%-])()' 

local closing_bracket = '^%s*(%))()'
local opening_bracket = '^%s*([%(])()'

local binary_Pattern = "^%s*([%^%%%+%-%*//,;])()"
local eq_pattern = "^%s*([~=]+)()"
local defined_vars = {['pi'] = math.pi}
local Huge = math.huge


local function _tonumber(x)
	local binary_num = string.match(x, '0b(%d+)') 

	if binary_num  then
		return tonumber(binary_num, 2)
	else
		return defined_vars[x]  or tonumber(x)
	end
end


local last_eq = true
local function _equals(x,y)

	if not last_eq then return false end

	if x == y then
		last_eq = y
		return true
	elseif last_eq == y then
		return true
	end
end


--[[
[binary_operator] = {precedence : int, operation, associativity : bool}
[unary_operator] = {precedence : int, operation}
associativity : false == left, true == right
--]]

local ops = {

	binary = {
		[','] = {0, function(x,y) return {x,y} end, false}, --// for functions with more than one arg

		['^'] = {6, function(x,y)return x^y end,true}, --// artihmic operators 
		['/'] = {5, function(x,y) return x/y end, false},
		['*'] = {5, function(x,y) return x*y end, false},
		['%'] = {5, function(x,y)return x%y end, false},
		['-'] = {3 ,function(x,y)return x-y end,false},
		['+'] = {3, function(x,y) return x+y end, false},


		['=='] = {1, _equals ,false}, --//equality operators can be extended to include and, not, or
		['~='] = {1, function(x,y) return not _equals(x,y) end ,false},

	},

	unary = {

		['math.abs'] = {Huge, math.abs}, --// functions
		['math.sqrt'] =  {Huge, math.sqrt}, 

		['math.max'] = {Huge, function(x)return math.max(unpack(x)) end}, 
		['math.random'] =  {Huge, function(x)return math.random(unpack(x))end}, 

		['-'] = {4, function(x) return -x end}, --artihmic unary

	}
}


local errs = {

	[0x1] = function(expect)

		return string.format(
			"Could not parse, expected: %s ", 
			expect
		)	
	end,

	[0x2] = function(found)

		return string.format(
			"could not parse found: '%s' ", 
			found
		)	
	end,
}



function evaluate(tree) --simple tree evalution | ex-case: '-(2+2)*5'
	local op, left, right = tree[1], tree[2],tree[3]

	if not left then return tree[1] end --  if not left then there are no operations | ex-case: '(2)'

	if (not right) then --//is unary;
		local fn = ops.unary[op][2]
		return fn(_tonumber(left[1]) or  evaluate(left)) -- only evaluate left tree
	else ---is binary
		local fn = ops.binary[op][2]

		local x = _tonumber(left[1]) or  evaluate(left) ---tonumber fails: 120_405
		local y = _tonumber(right[1]) or evaluate(right)


		return fn(x, y)--evaluate both right and left
	end
end




local function token_gen(source)  -- very simple token generator 
	local i = 1
	local expect_closing = 0
	local expect_token = 1

	return function()-- returns next token (and type) each call


		if expect_token == 1  then
			local unary, next = string.match(source, unary_Pattern, i)

			if unary then
				i = next; return unary, 'u' 
			end

			local opening, next = string.match(source, opening_bracket, i)

			if opening then
				expect_closing += 1
				i = next; return opening
			end

			local var, next, opening = string.match(source,var_Pattern, i)


			if var then
				if opening == '(' then
					i = next;expect_token = 1
					return var, 'u'
				else
					i = next;expect_token = 4
					return var
				end
			else

				local prev_opening = string.match(source, opening_bracket, i-1)
				local prev_operation = string.match(source, binary_Pattern, i-1)


				error(errs[0x1](string.format("opening bracket or variable after token: '%s'",
					(prev_opening or prev_operation))
					))
			end
		end

		if expect_token == 4 or expect_token == 5 then

			local binary_operator, next = string.match(source, binary_Pattern, i)


			if binary_operator then
				i = next;expect_token = 1
				return binary_operator, 'b' 
			end

			local eq_equal, next = string.match(source, eq_pattern, i)

			if eq_equal  then
				i = next;expect_token = 1
				return eq_equal, 'b'
			end
		end


		if expect_token == 4  or expect_token == 5 then
			local closing_brackets, next = string.match(source, closing_bracket, i)

			if closing_brackets then
				expect_closing -= 1
				i = next;expect_token = 5
				return ')'
			end
		end

		if  expect_closing ~= 0 then
			if expect_closing < 0 then
				error(errs[0x1]("'('"))
			else
				error(errs[0x1]("')'"))
			end
		end

		if expect_token == 5 and #source == i then
			error('found trailing token: '..string.match(source, '.+', i))
		end

		return nil -- return nil...were done!
	end
end


--[[
types...
u : unary operation 
b : binary operation
nil : other
--]]

function prec_climb.start(source, ast) --//start climb; ast == generate tree?

	local peak
	local flag = false
	local gen =  token_gen(source)---token_gen(source) or source:gmatch('.') in simple cases
	local binary_op, unary_op = ops.binary, ops.unary
	local type, last_type  


	local next = function() -- give back next 'token' to handle, while consuming
		local temp = peak; peak = nil

		if temp then
			type = last_type
			return temp
		else
			local token, _type =  gen()
			type = _type
			return token
		end
	end

	local function exp(p, tree)
		local next_token = next()

		if (not (next_token)) or next_token ==  ')'  then return tree end; 

		local operation = type == 'u' 
			and unary_op[next_token] or binary_op[next_token] 


		if next_token == '(' then 
			tree = exp(0) --start a new evaluation at depth 0 
			--//after closing bracket
			next_token, flag =  next(), true --//continue
			operation  = binary_op[next_token]	

			if  next_token ==  ')' 
				or (not (next_token)) then return tree end; 

		elseif type == 'u' then

			if ast then
				tree = {next_token,exp(operation[1])}
			else
				tree = operation[2](exp(operation[1])) 
			end

			if  peak  then --// if next is binary
				next_token, flag =  next(), true --//continue
				operation  = binary_op[next_token]
			else
				return tree --//no following operations
			end

		elseif not type then
			flag = true; 
			return exp(p, ast and {next_token} or _tonumber(next_token))
		end

		while (flag and p <= operation[1]) do 
			flag = false

			local right_tree = exp(operation[3] and operation[1] or operation[1]+1)
			local lower_token = next_token

			if right_tree then --//expanded calc becuase possible flasely returns 
				if ast then
					tree = {lower_token,tree, right_tree}
				else
					tree = operation[2](tree, right_tree) 
				end
			end

			if peak then
				next_token = next() 
				operation =  binary_op[next_token]
			end
		end

		last_type = type
		peak = next_token

		return tree;
	end

	return exp(0)
end


return prec_climb.start
