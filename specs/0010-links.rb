
describe "links DSL" do

  it "runs" do
    sql = I_Dig_Sql.new

    sql.[:block] do
      out_in(:blocked, :victim) do
        are :screen_name
        has :owner_id
      end

      type_id(:BLOCK_SCREEN) do
        out_in(:owner_id, :victim)
      end

      type_id(:BLOCK_OWNER) do
        out_in(:owner_id, :owner_id)
      end
    end

    sql.[:post] do
      out_in :pinner, :pub do
        are    :screen_name
        has    :owner_id
        not_in :block
      end

      order_by :created_at, :DESC
    end

    sql.[:follow] do
      out_in :fan, :star do
        are    :screen_name
        has    :owner_id
        not_in :block
      end
    end

    sql.[:feed] do

      select(
        'follow.star.screen_name',
        'post.*', 
        'max(post.pub.created_at)'
      )

      start :audience_id
      inner :follow
      inner :post

      group_by 'follow.star'

    end # === query


    sql.to_sql


  end # === it

end # === describe "links DSL"

