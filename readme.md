# GQL-Parser
## what it is for

 - parsing dlang type to gql schema at only compile time(the whole parsing things could be evaluated by pragma)
 - just raw dlang types with a little attributes(without any toxxx function or interface implementation)
 - schema is just a dlang char[], you can use it with any server support string stream or just send it as a text page
## how to use

    @object_("ObjectA") class  A
    {
	    int  a;
	    this()
	    {
		    a  =  0;
	    }
    }
    @input("InputB") class  B
    {
	    string  b;
	    this()
	    {
		    b  =  "";
		}
	}
	@scalar_("CustomScalar____1") struct  CustomScalar
	{
		int  c;
	}
	@enum_("CustomEnum_____1") enum  CustomEnum: string
	{
		A  =  "A",
		B  =  "B",
		C  =  "C"
	}
	class  Query
	{
		string  hello(string  name)
		{
			return  "hello "  ~  name;
		}
		A  getA()
		{
			return  new A();
		}
	}
	class  Mutation
	{
		void  addB(B[] b)
		{
			b  ~=  new B();
		}
	}
	pragma(msg, Schema.parseSchema!(Query, Mutation, void, A,  B,  CustomEnum,  CustomScalar)());
	// gonna see something like this:
	// type ObjectA {
	// 		a: Int!
	// }
	// input InputB {
	// 		b: String!
	// }
	// enum CustomEnum_____1 {
	// 		A
	// 		B
	// 		C
	// }
	// scalar CustomScalar____1
	// type query {
	// 		hello(name: String!): String!
	// 		getA(): ObjectA!
	// }
	// type mutation {
	// 		addB(b: [InputB!]!): Void!
	// }
## to-dos

 - [x] more compile time things
	 - [x] using parseSchema(Query, Mutation, Subscription) only, all extra types is auto-added
	 - [x] support interface checker at compile time
	 - [] gen Also gql documentation page, not just schema
- [ ] used as a vibe.d plugin
	- [ ] handler and controller for gql request that could be merged into Query type
	- [ ] gql request to dlang function call
	- [ ] schema docs though vibe.d
	- [ ] perfomance tests
- [ ] gql value to dlang value
- [x] interface support
- [ ] directive support