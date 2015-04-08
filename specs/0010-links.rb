
describe "links DSL" do

  it "runs" do
    sql = I_Dig_Sql.new

    sql.def(:block) do
      out_in(:blocked, :victim) {
        are  :screen_name
        have :owner_id
      }

      type_id(:BLOCK_SCREEN) {
        out_in(:owner_id, :victim)
      }

      type_id(:BLOCK_OWNER) {
        out_in(:owner_id, :owner_id)
      }
    end

    sql.def(:post) do
      out_in :pinner, :pub do
        are    :screen_name
        have   :owner_id
        not_in :block
      end

      order_by :created_at, :DESC
    end

    sql.def(:follow) do
      out_in :fan, :star do
        are    :screen_name
        have   :owner_id
        not_in :block
      end
    end

    sql.def(:feed) do

      get :follow, :post
      of  :audience_id
      group_by 'follow.star'

      select(
        'follow.star.screen_name',
        'post.*', 
        'max(post.pub.created_at)'
      )

    end # === query

    actual = sql.to_sql(:feed)

    puts "################################"
    puts actual
    puts "################################"

    sql(actual).should == "a"
  end # === it

end # === describe "links DSL"

