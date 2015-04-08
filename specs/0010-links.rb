
describe "links DSL" do

  it "runs" do
    sql = I_Dig_Sql.new

    sql.def(:block) do
      out_in(:blocked, :victim) do
        are  :screen_name
        have :owner_id
      end

      type_id(:BLOCK_SCREEN) do
        out_in(:owner_id, :victim)
      end

      type_id(:BLOCK_OWNER) do
        out_in(:owner_id, :owner_id)
      end
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

      select(
        'follow.star.screen_name',
        'post.*', 
        'max(post.pub.created_at)'
      )

      get :follow, :post
      of  :audience_id

      group_by 'follow.star'

    end # === query


    puts sql.to_sql
    sql.to_sql.should == "a"
  end # === it

end # === describe "links DSL"

