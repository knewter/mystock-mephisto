module Liquid
  class Assign < Tag
    Syntax = /(#{VariableSignature}+)\s*=\s*(#{QuotedFragment}+)/   
  
    def initialize(tag_name, markup, tokens)          
      if markup =~ Syntax
        @to = $1
        @from = $2
      else
        raise SyntaxError.new("Syntax Error in 'assign' - Valid syntax: assign [var] = [source]")
      end
      
      super      
    end
  
    def render(context)
       context.scopes.last[@to.to_s] = context[@from]
       ''
    end 
  
  end  
  
  Template.register_tag('assign', Assign)  
end